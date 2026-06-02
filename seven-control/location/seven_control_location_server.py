#!/usr/bin/env python3
import datetime as dt
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


def default_config_path():
	if os.name == "nt":
		return r"C:\ProgramData\SevenControl\location-server.env"
	if sys.platform == "darwin":
		return "/Library/Application Support/SevenControl/location-server.env"
	return "/etc/seven-control/location-server.env"


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


load_env_file(os.environ.get("SEVEN_CONTROL_LOCATION_CONFIG", default_config_path()))

DATA_DIR = Path(os.environ.get("SEVEN_CONTROL_LOCATION_DATA_DIR", "/var/lib/seven-control-location"))
ENROLL_TOKEN = os.environ.get("SEVEN_CONTROL_LOCATION_TOKEN", "")
ADMIN_TOKEN = os.environ.get("SEVEN_CONTROL_LOCATION_ADMIN_TOKEN", "")
BIND = os.environ.get("SEVEN_CONTROL_LOCATION_BIND", "127.0.0.1")
PORT = int(os.environ.get("SEVEN_CONTROL_LOCATION_PORT", "8765"))
DEFAULT_RETENTION_DAYS = int(os.environ.get("SEVEN_CONTROL_LOCATION_RETENTION_DAYS", "30"))


def now():
	return dt.datetime.now(dt.timezone.utc).isoformat()


def token_from_header(handler):
	header = handler.headers.get("Authorization", "")
	if not header.startswith("Bearer "):
		return ""
	return header.removeprefix("Bearer ").strip()


def send_json(handler, status, payload):
	body = json.dumps(payload, indent=2, sort_keys=True).encode("utf-8")
	handler.send_response(status)
	handler.send_header("Content-Type", "application/json")
	handler.send_header("Content-Length", str(len(body)))
	handler.end_headers()
	handler.wfile.write(body)


def parse_timestamp(value):
	if not value:
		return None
	try:
		return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
	except ValueError:
		return None


def line_count(path):
	if not path.exists():
		return 0
	with path.open("r", encoding="utf-8") as handle:
		return sum(1 for _ in handle)


def load_json_file(path):
	try:
		with path.open("r", encoding="utf-8") as handle:
			return json.load(handle)
	except (OSError, json.JSONDecodeError):
		return None


def audit(event, remote, detail):
	DATA_DIR.mkdir(parents=True, exist_ok=True)
	record = {
		"timestamp": now(),
		"event": event,
		"remote": remote,
		"detail": detail,
	}
	with (DATA_DIR / "audit.jsonl").open("a", encoding="utf-8") as handle:
		handle.write(json.dumps(record, sort_keys=True) + "\n")


class Handler(BaseHTTPRequestHandler):
	server_version = "SevenControlLocation/1.0"

	def log_message(self, fmt, *args):
		audit("http_log", self.client_address[0], fmt % args)

	def do_POST(self):
		if self.path != "/api/location":
			send_json(self, 404, {"error": "not_found"})
			return

		if not ENROLL_TOKEN or token_from_header(self) != ENROLL_TOKEN:
			audit("submit_denied", self.client_address[0], "bad_token")
			send_json(self, 403, {"error": "forbidden"})
			return

		try:
			length = int(self.headers.get("Content-Length", "0"))
		except ValueError:
			length = 0
		if length <= 0 or length > 1024 * 1024:
			send_json(self, 400, {"error": "invalid_body_size"})
			return

		try:
			payload = json.loads(self.rfile.read(length).decode("utf-8"))
		except json.JSONDecodeError:
			send_json(self, 400, {"error": "invalid_json"})
			return

		device_id = str(payload.get("device_id", "")).strip()
		if not device_id:
			send_json(self, 400, {"error": "missing_device_id"})
			return

		DATA_DIR.mkdir(parents=True, exist_ok=True)
		(DATA_DIR / "latest").mkdir(exist_ok=True)
		payload["received_at"] = now()
		payload["remote_addr"] = self.client_address[0]

		with (DATA_DIR / "events.jsonl").open("a", encoding="utf-8") as handle:
			handle.write(json.dumps(payload, sort_keys=True) + "\n")
		with (DATA_DIR / "latest" / f"{device_id}.json").open("w", encoding="utf-8") as handle:
			json.dump(payload, handle, indent=2, sort_keys=True)

		audit("submit_ok", self.client_address[0], device_id)
		send_json(self, 200, {"status": "ok", "device_id": device_id})

	def do_GET(self):
		if not ADMIN_TOKEN:
			send_json(self, 503, {"error": "admin_token_not_configured"})
			return
		if token_from_header(self) != ADMIN_TOKEN:
			audit("admin_denied", self.client_address[0], "bad_token")
			send_json(self, 403, {"error": "forbidden"})
			return

		parsed = urlparse(self.path)
		query = parse_qs(parsed.query)
		if parsed.path == "/api/devices":
			latest_dir = DATA_DIR / "latest"
			devices = []
			if latest_dir.exists():
				for path in sorted(latest_dir.glob("*.json")):
					payload = load_json_file(path)
					if payload is not None:
						devices.append(payload)
			audit("admin_list", self.client_address[0], f"{len(devices)} devices")
			send_json(self, 200, {"devices": devices})
			return

		if parsed.path == "/api/status":
			latest_dir = DATA_DIR / "latest"
			devices = len(list(latest_dir.glob("*.json"))) if latest_dir.exists() else 0
			payload = {
				"status": "ok",
				"server_time": now(),
				"data_dir": str(DATA_DIR),
				"devices": devices,
				"events": line_count(DATA_DIR / "events.jsonl"),
				"audit_events": line_count(DATA_DIR / "audit.jsonl"),
				"retention_days": DEFAULT_RETENTION_DAYS,
			}
			audit("admin_status", self.client_address[0], f"{devices} devices")
			send_json(self, 200, payload)
			return

		if parsed.path == "/api/device":
			device_id = query.get("id", [""])[0]
			path = DATA_DIR / "latest" / f"{device_id}.json"
			if not device_id or not path.exists():
				send_json(self, 404, {"error": "device_not_found"})
				return
			payload = load_json_file(path)
			if payload is None:
				send_json(self, 500, {"error": "device_record_corrupt"})
				return
			audit("admin_get", self.client_address[0], device_id)
			send_json(self, 200, payload)
			return

		if parsed.path == "/api/audit":
			try:
				limit = int(query.get("limit", ["50"])[0])
			except ValueError:
				send_json(self, 400, {"error": "invalid_limit"})
				return
			limit = max(1, min(limit, 500))
			path = DATA_DIR / "audit.jsonl"
			items = []
			if path.exists():
				with path.open("r", encoding="utf-8") as handle:
					lines = handle.readlines()[-limit:]
				for line in lines:
					try:
						items.append(json.loads(line))
					except json.JSONDecodeError:
						continue
			audit("admin_audit", self.client_address[0], f"{len(items)} records")
			send_json(self, 200, {"audit": items})
			return

		send_json(self, 404, {"error": "not_found"})

	def do_DELETE(self):
		if not ADMIN_TOKEN:
			send_json(self, 503, {"error": "admin_token_not_configured"})
			return
		if token_from_header(self) != ADMIN_TOKEN:
			audit("admin_denied", self.client_address[0], "bad_token")
			send_json(self, 403, {"error": "forbidden"})
			return

		parsed = urlparse(self.path)
		query = parse_qs(parsed.query)
		if parsed.path != "/api/events":
			send_json(self, 404, {"error": "not_found"})
			return

		try:
			days = int(query.get("older_than_days", [str(DEFAULT_RETENTION_DAYS)])[0])
		except ValueError:
			send_json(self, 400, {"error": "invalid_days"})
			return
		if days < 1:
			send_json(self, 400, {"error": "days_must_be_positive"})
			return

		path = DATA_DIR / "events.jsonl"
		if not path.exists():
			send_json(self, 200, {"status": "ok", "kept": 0, "purged": 0})
			return

		cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=days)
		kept = []
		purged = 0
		with path.open("r", encoding="utf-8") as handle:
			for line in handle:
				try:
					item = json.loads(line)
				except json.JSONDecodeError:
					purged += 1
					continue
				timestamp = parse_timestamp(item.get("received_at") or item.get("timestamp"))
				if timestamp is not None and timestamp < cutoff:
					purged += 1
				else:
					kept.append(json.dumps(item, sort_keys=True))

		tmp_path = path.with_suffix(".jsonl.tmp")
		with tmp_path.open("w", encoding="utf-8") as handle:
			for line in kept:
				handle.write(line + "\n")
		tmp_path.replace(path)

		audit("admin_purge", self.client_address[0], f"older_than_days={days} purged={purged}")
		send_json(self, 200, {"status": "ok", "kept": len(kept), "purged": purged})


def main():
	if not ENROLL_TOKEN:
		raise SystemExit("SEVEN_CONTROL_LOCATION_TOKEN est requis.")
	DATA_DIR.mkdir(parents=True, exist_ok=True)
	server = ThreadingHTTPServer((BIND, PORT), Handler)
	print(f"Seven Control Location server listening on http://{BIND}:{PORT}")
	server.serve_forever()


if __name__ == "__main__":
	main()
