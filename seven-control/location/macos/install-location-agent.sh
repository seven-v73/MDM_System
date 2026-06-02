#!/usr/bin/env bash
set -euo pipefail

install_dir="/usr/local/seven-control"
config_dir="/Library/Application Support/SevenControl"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
location_dir="$(cd "$script_dir/.." && pwd)"

if [ "$(id -u)" -ne 0 ]; then
	printf 'Lancez ce script avec sudo.\n' >&2
	exit 1
fi

command -v python3 >/dev/null 2>&1 || {
	printf 'python3 est introuvable. Installez Python 3 avant de continuer.\n' >&2
	exit 1
}

install -d "$install_dir/location" "$config_dir" /Library/LaunchDaemons
install -m 0755 "$location_dir/seven_control_location_agent.py" "$install_dir/location/seven_control_location_agent.py"

if [ ! -f "$config_dir/location-agent.env" ]; then
	install -m 0600 "$location_dir/agent.env.example" "$config_dir/location-agent.env"
fi

if [ ! -f "$config_dir/location-notice.accepted" ]; then
	printf 'Seven Control Location active sur cette machine administree.\n' > "$config_dir/location-notice.accepted"
	chmod 0644 "$config_dir/location-notice.accepted"
fi

install -m 0644 "$script_dir/com.sevencontrol.location-agent.plist" /Library/LaunchDaemons/com.sevencontrol.location-agent.plist
launchctl bootstrap system /Library/LaunchDaemons/com.sevencontrol.location-agent.plist 2>/dev/null || true
launchctl enable system/com.sevencontrol.location-agent
launchctl kickstart -k system/com.sevencontrol.location-agent

printf 'Seven Control Location Agent installe sur macOS.\n'
printf 'Configuration: %s/location-agent.env\n' "$config_dir"
