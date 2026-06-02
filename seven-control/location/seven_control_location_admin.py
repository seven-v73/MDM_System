#!/usr/bin/env python3
import argparse
import csv
import datetime as dt
import json
import os
import secrets
import sys
import urllib.error
import urllib.parse
import urllib.request


def default_config_path():
	if os.name == "nt":
		return r"C:\ProgramData\SevenControl\location-admin.env"
	if sys.platform == "darwin":
		return "/Library/Application Support/SevenControl/location-admin.env"
	return "/etc/seven-control/location-admin.env"


def load_env_file(path):
	try:
		with open(path, "r", encoding="utf-8") as handle:
			for raw_line in handle:
				line = raw_line.strip()
				if not line or line.startswith("#") or "=" not in line:
					continue
				key, value = line.split("=", 1)
				key = key.strip()
				value = value.strip().strip('"').strip("'")
				if key and key not in os.environ:
					os.environ[key] = value
	except OSError:
		return


def request_json(method, base_url, token, path):
	url = base_url.rstrip("/") + path
	request = urllib.request.Request(
		url,
		method=method,
		headers={
			"Authorization": f"Bearer {token}",
			"User-Agent": "SevenControlLocationAdmin/1.0",
		},
	)
	try:
		with urllib.request.urlopen(request, timeout=15) as response:
			return json.load(response)
	except urllib.error.HTTPError as exc:
		body = exc.read().decode("utf-8", errors="replace")
		raise SystemExit(f"Erreur HTTP {exc.code}: {body}") from exc
	except urllib.error.URLError as exc:
		raise SystemExit(f"Serveur injoignable: {exc}") from exc


def gps_summary(device):
	gps = device.get("sources", {}).get("gps")
	if not gps:
		return ""
	lat = gps.get("latitude")
	lon = gps.get("longitude")
	if lat is None or lon is None:
		return ""
	return f"{lat},{lon}"


def parse_timestamp(value):
	if not value:
		return None
	try:
		return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
	except ValueError:
		return None


def is_stale(device, stale_minutes):
	if stale_minutes <= 0:
		return False
	timestamp = parse_timestamp(device.get("received_at"))
	if timestamp is None:
		return True
	return timestamp < dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=stale_minutes)


def print_table(devices, stale_minutes=0):
	print(f"{'DEVICE ID':<22} {'NOM':<24} {'RECU':<28} {'AGE':<8} {'ETAT':<8} {'GPS':<24}")
	for device in devices:
		timestamp = parse_timestamp(device.get("received_at"))
		age = ""
		if timestamp is not None:
			age_delta = dt.datetime.now(dt.timezone.utc) - timestamp
			age = f"{int(age_delta.total_seconds() // 60)}m"
		state = "stale" if is_stale(device, stale_minutes) else "ok"
		print(
			f"{str(device.get('device_id', '')):<22} "
			f"{str(device.get('device_name', '')):<24} "
			f"{str(device.get('received_at', '')):<28} "
			f"{age:<8} "
			f"{state:<8} "
			f"{gps_summary(device):<24}"
		)


def export_csv(devices, output):
	fieldnames = ["device_id", "device_name", "hostname", "received_at", "remote_addr", "gps", "public_ip"]
	target = sys.stdout if output == "-" else open(output, "w", encoding="utf-8", newline="")
	with target:
		writer = csv.DictWriter(target, fieldnames=fieldnames)
		writer.writeheader()
		for device in devices:
			writer.writerow({
				"device_id": device.get("device_id", ""),
				"device_name": device.get("device_name", ""),
				"hostname": device.get("hostname", ""),
				"received_at": device.get("received_at", ""),
				"remote_addr": device.get("remote_addr", ""),
				"gps": gps_summary(device),
				"public_ip": device.get("sources", {}).get("public_ip", ""),
			})


def export_geojson(devices, output):
	features = []
	for device in devices:
		gps = device.get("sources", {}).get("gps") or {}
		lat = gps.get("latitude")
		lon = gps.get("longitude")
		if lat is None or lon is None:
			continue
		features.append({
			"type": "Feature",
			"geometry": {
				"type": "Point",
				"coordinates": [lon, lat],
			},
			"properties": {
				"device_id": device.get("device_id", ""),
				"device_name": device.get("device_name", ""),
				"hostname": device.get("hostname", ""),
				"received_at": device.get("received_at", ""),
				"accuracy_m": gps.get("accuracy_m", ""),
				"remote_addr": device.get("remote_addr", ""),
			},
		})
	payload = {
		"type": "FeatureCollection",
		"features": features,
	}
	target = sys.stdout if output == "-" else open(output, "w", encoding="utf-8")
	with target:
		json.dump(payload, target, indent=2, sort_keys=True)
		target.write("\n")


def main():
	load_env_file(os.environ.get("SEVEN_CONTROL_LOCATION_CONFIG", default_config_path()))

	parser = argparse.ArgumentParser(description="Administration Seven Control Location")
	parser.add_argument("--server", default=os.environ.get("SEVEN_CONTROL_LOCATION_SERVER_URL", "http://127.0.0.1:8765"))
	parser.add_argument("--token", default=os.environ.get("SEVEN_CONTROL_LOCATION_ADMIN_TOKEN", ""))
	subparsers = parser.add_subparsers(dest="command", required=True)

	list_parser = subparsers.add_parser("list", help="Lister les dernieres positions")
	list_parser.add_argument("--stale-minutes", type=int, default=0, help="Marquer stale si aucun signal depuis N minutes")

	get_parser = subparsers.add_parser("get", help="Afficher une machine")
	get_parser.add_argument("device_id")

	subparsers.add_parser("status", help="Afficher l'etat du serveur")

	export_parser = subparsers.add_parser("export-csv", help="Exporter les dernieres positions en CSV")
	export_parser.add_argument("output", nargs="?", default="-")

	geojson_parser = subparsers.add_parser("export-geojson", help="Exporter les positions GPS en GeoJSON")
	geojson_parser.add_argument("output", nargs="?", default="-")

	audit_parser = subparsers.add_parser("audit", help="Afficher les derniers evenements d'audit")
	audit_parser.add_argument("--limit", type=int, default=50)

	purge_parser = subparsers.add_parser("purge", help="Purger l'historique plus ancien que N jours")
	purge_parser.add_argument("--older-than-days", type=int, required=True)

	token_parser = subparsers.add_parser("generate-token", help="Generer un token fort")
	token_parser.add_argument("--bytes", type=int, default=32)

	args = parser.parse_args()
	if args.command == "generate-token":
		if args.bytes < 16:
			raise SystemExit("--bytes doit etre >= 16.")
		print(secrets.token_urlsafe(args.bytes))
		return

	if not args.token:
		raise SystemExit("Token admin manquant: utilisez --token ou SEVEN_CONTROL_LOCATION_ADMIN_TOKEN.")

	if args.command == "list":
		data = request_json("GET", args.server, args.token, "/api/devices")
		print_table(data.get("devices", []), args.stale_minutes)
	elif args.command == "get":
		device_id = urllib.parse.quote(args.device_id)
		data = request_json("GET", args.server, args.token, f"/api/device?id={device_id}")
		print(json.dumps(data, indent=2, sort_keys=True))
	elif args.command == "status":
		data = request_json("GET", args.server, args.token, "/api/status")
		print(json.dumps(data, indent=2, sort_keys=True))
	elif args.command == "export-csv":
		data = request_json("GET", args.server, args.token, "/api/devices")
		export_csv(data.get("devices", []), args.output)
	elif args.command == "export-geojson":
		data = request_json("GET", args.server, args.token, "/api/devices")
		export_geojson(data.get("devices", []), args.output)
	elif args.command == "audit":
		data = request_json("GET", args.server, args.token, f"/api/audit?limit={args.limit}")
		for item in data.get("audit", []):
			print(json.dumps(item, sort_keys=True))
	elif args.command == "purge":
		data = request_json("DELETE", args.server, args.token, f"/api/events?older_than_days={args.older_than_days}")
		print(json.dumps(data, indent=2, sort_keys=True))


if __name__ == "__main__":
	main()
