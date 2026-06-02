#!/usr/bin/env python3
import datetime as dt
import hashlib
import json
import os
import platform
import socket
import subprocess
import sys
import urllib.error
import urllib.request


def env(name, default=""):
	return os.environ.get(name, default).strip()


def run_command(args, timeout=4):
	try:
		return subprocess.run(
			args,
			check=False,
			stdout=subprocess.PIPE,
			stderr=subprocess.DEVNULL,
			text=True,
			timeout=timeout,
		).stdout.strip()
	except (FileNotFoundError, subprocess.TimeoutExpired):
		return ""


def read_first_existing(paths):
	for path in paths:
		try:
			with open(path, "r", encoding="utf-8") as handle:
				value = handle.read().strip()
				if value:
					return value
		except OSError:
			continue
	return ""


def device_id():
	configured = env("SEVEN_CONTROL_DEVICE_ID")
	if configured:
		return configured

	seed = read_first_existing([
		"/etc/machine-id",
		"/var/lib/dbus/machine-id",
	]) or socket.gethostname()
	return "sc-" + hashlib.sha256(seed.encode("utf-8")).hexdigest()[:16]


def local_ips():
	output = run_command(["ip", "-j", "addr", "show"])
	if output:
		try:
			data = json.loads(output)
			ips = []
			for interface in data:
				name = interface.get("ifname", "")
				if name == "lo":
					continue
				for address in interface.get("addr_info", []):
					if address.get("family") == "inet":
						ips.append({
							"interface": name,
							"address": address.get("local", ""),
						})
			return [item for item in ips if item["address"]]
		except json.JSONDecodeError:
			return []
	return []


def wifi_scan():
	output = run_command(["nmcli", "-t", "-f", "ACTIVE,SSID,BSSID,SIGNAL", "dev", "wifi", "list"], timeout=8)
	networks = []
	for line in output.splitlines():
		parts = line.split(":")
		if len(parts) < 4:
			continue
		active, ssid, bssid, signal = parts[0], parts[1], ":".join(parts[2:-1]), parts[-1]
		networks.append({
			"active": active == "yes",
			"ssid": ssid,
			"bssid": bssid,
			"signal": signal,
		})
	return networks[:20]


def gps_position():
	output = run_command(["gpspipe", "-w", "-n", "12"], timeout=8)
	for line in output.splitlines():
		try:
			item = json.loads(line)
		except json.JSONDecodeError:
			continue
		if item.get("class") == "TPV" and "lat" in item and "lon" in item:
			return {
				"source": "gpsd",
				"latitude": item.get("lat"),
				"longitude": item.get("lon"),
				"accuracy_m": item.get("epx") or item.get("epy"),
			}
	return None


def public_ip():
	url = env("SEVEN_CONTROL_PUBLIC_IP_URL")
	if not url:
		return ""
	try:
		with urllib.request.urlopen(url, timeout=4) as response:
			return response.read(200).decode("utf-8", errors="replace").strip()
	except (OSError, urllib.error.URLError):
		return ""


def post_json(url, token, payload):
	body = json.dumps(payload, sort_keys=True).encode("utf-8")
	request = urllib.request.Request(
		url,
		data=body,
		method="POST",
		headers={
			"Authorization": f"Bearer {token}",
			"Content-Type": "application/json",
			"User-Agent": "SevenControlLocationAgent/1.0",
		},
	)
	with urllib.request.urlopen(request, timeout=10) as response:
		return response.status, response.read().decode("utf-8", errors="replace")


def main():
	server_url = env("SEVEN_CONTROL_LOCATION_SERVER_URL")
	token = env("SEVEN_CONTROL_LOCATION_TOKEN")
	notice_file = env("SEVEN_CONTROL_LOCATION_NOTICE_FILE", "/etc/seven-control/location-notice.accepted")

	if not server_url or not token:
		print("SEVEN_CONTROL_LOCATION_SERVER_URL et SEVEN_CONTROL_LOCATION_TOKEN sont requis.", file=sys.stderr)
		return 2

	if not os.path.exists(notice_file):
		print(f"Localisation non activee: fichier d'information manquant: {notice_file}", file=sys.stderr)
		return 3

	position = gps_position()
	payload = {
		"schema": "seven-control-location-v1",
		"timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
		"device_id": device_id(),
		"device_name": env("SEVEN_CONTROL_DEVICE_NAME", socket.gethostname()),
		"hostname": socket.gethostname(),
		"os": platform.platform(),
		"sources": {
			"gps": position,
			"wifi": wifi_scan(),
			"local_ips": local_ips(),
			"public_ip": public_ip(),
		},
		"notice": {
			"enabled": True,
			"notice_file": notice_file,
		},
	}

	status, response = post_json(server_url.rstrip("/") + "/api/location", token, payload)
	print(f"Seven Control Location: envoi termine HTTP {status}: {response.strip()}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
