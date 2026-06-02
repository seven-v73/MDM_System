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


def default_config_path():
	if os.name == "nt":
		return r"C:\ProgramData\SevenControl\location-agent.env"
	if sys.platform == "darwin":
		return "/Library/Application Support/SevenControl/location-agent.env"
	return "/etc/seven-control/location-agent.env"


def default_notice_path():
	if os.name == "nt":
		return r"C:\ProgramData\SevenControl\location-notice.accepted"
	if sys.platform == "darwin":
		return "/Library/Application Support/SevenControl/location-notice.accepted"
	return "/etc/seven-control/location-notice.accepted"


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

	if os.name == "nt":
		try:
			import winreg
			with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Cryptography") as key:
				seed, _ = winreg.QueryValueEx(key, "MachineGuid")
				return "sc-" + hashlib.sha256(seed.encode("utf-8")).hexdigest()[:16]
		except OSError:
			pass

	if sys.platform == "darwin":
		output = run_command(["ioreg", "-rd1", "-c", "IOPlatformExpertDevice"])
		for line in output.splitlines():
			if "IOPlatformUUID" in line and "=" in line:
				seed = line.split("=", 1)[1].strip().strip('"')
				return "sc-" + hashlib.sha256(seed.encode("utf-8")).hexdigest()[:16]

	seed = read_first_existing([
		"/etc/machine-id",
		"/var/lib/dbus/machine-id",
	]) or socket.gethostname()
	return "sc-" + hashlib.sha256(seed.encode("utf-8")).hexdigest()[:16]


def local_ips():
	seen = set()
	ips = []
	for info in socket.getaddrinfo(socket.gethostname(), None, family=socket.AF_INET):
		address = info[4][0]
		if address and not address.startswith("127.") and address not in seen:
			seen.add(address)
			ips.append({"interface": "system", "address": address})

	output = run_command(["ip", "-j", "addr", "show"])
	if output:
		try:
			data = json.loads(output)
			for interface in data:
				name = interface.get("ifname", "")
				if name == "lo":
					continue
				for address in interface.get("addr_info", []):
					local = address.get("local", "")
					if address.get("family") == "inet" and local and local not in seen:
						seen.add(local)
						ips.append({
							"interface": name,
							"address": local,
						})
			return [item for item in ips if item["address"]]
		except json.JSONDecodeError:
			return ips

	if os.name == "nt":
		output = run_command(["ipconfig"])
		current = "system"
		for line in output.splitlines():
			stripped = line.strip()
			if stripped.endswith(":"):
				current = stripped[:-1]
			if "IPv4" in stripped and ":" in stripped:
				address = stripped.split(":", 1)[1].strip()
				if address and address not in seen:
					seen.add(address)
					ips.append({"interface": current, "address": address})

	return ips


def wifi_scan():
	if os.name == "nt":
		output = run_command(["netsh", "wlan", "show", "networks", "mode=bssid"], timeout=8)
		networks = []
		current = {}
		for line in output.splitlines():
			stripped = line.strip()
			if stripped.startswith("SSID ") and ":" in stripped:
				if current:
					networks.append(current)
				current = {"ssid": stripped.split(":", 1)[1].strip()}
			elif stripped.startswith("BSSID ") and ":" in stripped:
				current["bssid"] = stripped.split(":", 1)[1].strip()
			elif stripped.startswith("Signal") and ":" in stripped:
				current["signal"] = stripped.split(":", 1)[1].strip().rstrip("%")
		if current:
			networks.append(current)
		return networks[:20]

	if sys.platform == "darwin":
		airport = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
		output = run_command([airport, "-s"], timeout=8)
		networks = []
		for line in output.splitlines()[1:]:
			parts = line.split()
			if len(parts) >= 3:
				networks.append({
					"ssid": " ".join(parts[:-5]) if len(parts) > 5 else parts[0],
					"bssid": parts[-5] if len(parts) > 5 else "",
					"signal": parts[-4] if len(parts) > 5 else "",
				})
		return networks[:20]

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


def diagnose(server_url, token, notice_file):
	status = 0
	print("Seven Control Location Agent diagnostic")
	print(f"OS: {platform.platform()}")
	print(f"Device ID: {device_id()}")
	print(f"Device name: {env('SEVEN_CONTROL_DEVICE_NAME', socket.gethostname())}")
	if server_url:
		print(f"Server URL: {server_url}")
	else:
		print("Server URL: manquant")
		status = 1
	if token:
		print("Enroll token: configure")
	else:
		print("Enroll token: manquant")
		status = 1
	if os.path.exists(notice_file):
		print(f"Notice file: present ({notice_file})")
	else:
		print(f"Notice file: manquant ({notice_file})")
		status = 1
	print(f"Local IPs: {len(local_ips())}")
	print(f"Wi-Fi networks visible: {len(wifi_scan())}")
	print(f"GPS available: {'yes' if gps_position() else 'no'}")
	if server_url:
		try:
			with urllib.request.urlopen(server_url.rstrip("/") + "/api/status", timeout=5) as response:
				print(f"Server reachability: HTTP {response.status}")
		except urllib.error.HTTPError as exc:
			if exc.code in (403, 503):
				print(f"Server reachability: HTTP {exc.code} (reachable, admin endpoint protected)")
			else:
				print(f"Server reachability: failed (HTTP {exc.code})")
				status = 1
		except (OSError, urllib.error.URLError) as exc:
			print(f"Server reachability: failed ({exc})")
			status = 1
	return status


def main():
	load_env_file(env("SEVEN_CONTROL_LOCATION_CONFIG", default_config_path()))
	if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1] not in ("--diagnose", "--help", "-h")):
		print("Usage: seven_control_location_agent.py [--diagnose]", file=sys.stderr)
		return 2
	server_url = env("SEVEN_CONTROL_LOCATION_SERVER_URL")
	token = env("SEVEN_CONTROL_LOCATION_TOKEN")
	notice_file = env("SEVEN_CONTROL_LOCATION_NOTICE_FILE", default_notice_path())

	if len(sys.argv) == 2 and sys.argv[1] in ("--help", "-h"):
		print("Usage: seven_control_location_agent.py [--diagnose]")
		return 0

	if len(sys.argv) == 2 and sys.argv[1] == "--diagnose":
		return diagnose(server_url, token, notice_file)

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
