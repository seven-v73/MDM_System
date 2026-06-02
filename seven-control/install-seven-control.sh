#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
Usage: install-seven-control.sh [--prefix DIR]

Options:
  --prefix DIR  Repertoire d'installation des fichiers Seven Control (defaut: /opt/seven-control)
EOF
	exit "${1:-2}"
}

prefix="/opt/seven-control"

while [ "$#" -gt 0 ]; do
	case "$1" in
		--prefix)
			[ "$#" -ge 2 ] || usage
			prefix="$2"
			shift 2
			;;
		-h|--help)
			usage 0
			;;
		*)
			usage
			;;
	esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tool_root="$repo_root/seven-control"
sudo_cmd=()
if [ "$(id -u)" -ne 0 ]; then
	sudo_cmd=(sudo)
fi

"${sudo_cmd[@]}" install -d "$prefix" "$prefix/location" "$prefix/location/windows" "$prefix/location/macos" "$prefix/arch" "$prefix/linux" "$prefix/windows" "$prefix/macos" /usr/local/bin /usr/local/share/applications /usr/local/lib/systemd/system
"${sudo_cmd[@]}" install -m 0755 "$tool_root/import-inventory.sh" "$prefix/import-inventory.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/seven-control-lock.sh" "$prefix/seven-control-lock.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/apply-profile.sh" "$prefix/apply-profile.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/validate-inventory.sh" "$prefix/validate-inventory.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/locate-machine.sh" "$prefix/locate-machine.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/health-check.sh" "$prefix/health-check.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/backup-config.sh" "$prefix/backup-config.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/launch-veyon-gui.sh" "$prefix/launch-veyon-gui.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/location/seven_control_location_agent.py" "$prefix/location/seven_control_location_agent.py"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/location/seven_control_location_server.py" "$prefix/location/seven_control_location_server.py"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/README.md" "$prefix/README.md"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/arch/README.md" "$prefix/arch/README.md"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/linux/README.md" "$prefix/linux/README.md"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/windows/README.md" "$prefix/windows/README.md"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/macos/README.md" "$prefix/macos/README.md"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/location/README.md" "$prefix/location/README.md"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/location/agent.env.example" "$prefix/location/agent.env.example"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/location/server.env.example" "$prefix/location/server.env.example"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/location/windows/install-location-agent.ps1" "$prefix/location/windows/install-location-agent.ps1"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/location/windows/run-location-agent.ps1" "$prefix/location/windows/run-location-agent.ps1"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/location/macos/com.sevencontrol.location-agent.plist" "$prefix/location/macos/com.sevencontrol.location-agent.plist"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/location/macos/install-location-agent.sh" "$prefix/location/macos/install-location-agent.sh"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/inventory.example.csv" "$prefix/inventory.example.csv"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/hosts.example.txt" "$prefix/hosts.example.txt"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/location/seven-control-location-agent.service" /usr/local/lib/systemd/system/seven-control-location-agent.service
"${sudo_cmd[@]}" install -m 0644 "$tool_root/location/seven-control-location-agent.timer" /usr/local/lib/systemd/system/seven-control-location-agent.timer
"${sudo_cmd[@]}" install -m 0644 "$tool_root/location/seven-control-location-server.service" /usr/local/lib/systemd/system/seven-control-location-server.service
"${sudo_cmd[@]}" install -m 0644 "$tool_root/desktop/seven-control-master.desktop" /usr/local/share/applications/seven-control-master.desktop
"${sudo_cmd[@]}" install -m 0644 "$tool_root/desktop/seven-control-configurator.desktop" /usr/local/share/applications/seven-control-configurator.desktop

"${sudo_cmd[@]}" ln -sf "$prefix/seven-control-lock.sh" /usr/local/bin/seven-control-lock
"${sudo_cmd[@]}" ln -sf "$prefix/import-inventory.sh" /usr/local/bin/seven-control-import-inventory
"${sudo_cmd[@]}" ln -sf "$prefix/apply-profile.sh" /usr/local/bin/seven-control-apply-profile
"${sudo_cmd[@]}" ln -sf "$prefix/validate-inventory.sh" /usr/local/bin/seven-control-validate-inventory
"${sudo_cmd[@]}" ln -sf "$prefix/locate-machine.sh" /usr/local/bin/seven-control-locate
"${sudo_cmd[@]}" ln -sf "$prefix/health-check.sh" /usr/local/bin/seven-control-health-check
"${sudo_cmd[@]}" ln -sf "$prefix/backup-config.sh" /usr/local/bin/seven-control-backup-config
"${sudo_cmd[@]}" ln -sf "$prefix/launch-veyon-gui.sh" /usr/local/bin/seven-control-master
"${sudo_cmd[@]}" ln -sf "$prefix/launch-veyon-gui.sh" /usr/local/bin/seven-control-configurator
"${sudo_cmd[@]}" ln -sf "$prefix/location/seven_control_location_agent.py" /usr/local/bin/seven-control-location-agent
"${sudo_cmd[@]}" ln -sf "$prefix/location/seven_control_location_server.py" /usr/local/bin/seven-control-location-server

for legacy_command in \
	simplon-lock \
	simplon-import-inventory \
	simplon-apply-profile \
	simplon-validate-inventory \
	simplon-locate \
	simplon-health-check \
	simplon-backup-config \
	simplon-veyon-master \
	simplon-veyon-configurator \
	simplon-location-agent \
	simplon-location-server
do
	if [ -L "/usr/local/bin/$legacy_command" ]; then
		"${sudo_cmd[@]}" rm -f "/usr/local/bin/$legacy_command"
	fi
done

if ! /usr/local/bin/seven-control-configurator --version | grep -q 'admin-wayland'; then
	printf 'Installation du wrapper graphique incomplete.\n' >&2
	exit 1
fi

printf 'Outils Seven Control installes dans %s.\n' "$prefix"
printf 'Commandes disponibles: seven-control-lock, seven-control-import-inventory, seven-control-apply-profile, seven-control-validate-inventory, seven-control-locate, seven-control-health-check, seven-control-backup-config, seven-control-master, seven-control-configurator, seven-control-location-agent, seven-control-location-server\n'
