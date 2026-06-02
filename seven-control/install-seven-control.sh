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

"${sudo_cmd[@]}" install -d "$prefix" /usr/local/bin /usr/local/share/applications
"${sudo_cmd[@]}" install -m 0755 "$tool_root/import-inventory.sh" "$prefix/import-inventory.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/seven-control-lock.sh" "$prefix/seven-control-lock.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/apply-profile.sh" "$prefix/apply-profile.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/validate-inventory.sh" "$prefix/validate-inventory.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/health-check.sh" "$prefix/health-check.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/backup-config.sh" "$prefix/backup-config.sh"
"${sudo_cmd[@]}" install -m 0755 "$tool_root/launch-veyon-gui.sh" "$prefix/launch-veyon-gui.sh"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/README.md" "$prefix/README.md"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/inventory.example.csv" "$prefix/inventory.example.csv"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/hosts.example.txt" "$prefix/hosts.example.txt"
"${sudo_cmd[@]}" install -m 0644 "$tool_root/desktop/seven-control-master.desktop" /usr/local/share/applications/seven-control-master.desktop
"${sudo_cmd[@]}" install -m 0644 "$tool_root/desktop/seven-control-configurator.desktop" /usr/local/share/applications/seven-control-configurator.desktop

"${sudo_cmd[@]}" ln -sf "$prefix/seven-control-lock.sh" /usr/local/bin/seven-control-lock
"${sudo_cmd[@]}" ln -sf "$prefix/import-inventory.sh" /usr/local/bin/seven-control-import-inventory
"${sudo_cmd[@]}" ln -sf "$prefix/apply-profile.sh" /usr/local/bin/seven-control-apply-profile
"${sudo_cmd[@]}" ln -sf "$prefix/validate-inventory.sh" /usr/local/bin/seven-control-validate-inventory
"${sudo_cmd[@]}" ln -sf "$prefix/health-check.sh" /usr/local/bin/seven-control-health-check
"${sudo_cmd[@]}" ln -sf "$prefix/backup-config.sh" /usr/local/bin/seven-control-backup-config
"${sudo_cmd[@]}" ln -sf "$prefix/launch-veyon-gui.sh" /usr/local/bin/seven-control-master
"${sudo_cmd[@]}" ln -sf "$prefix/launch-veyon-gui.sh" /usr/local/bin/seven-control-configurator

for legacy_command in \
	simplon-lock \
	simplon-import-inventory \
	simplon-apply-profile \
	simplon-validate-inventory \
	simplon-health-check \
	simplon-backup-config \
	simplon-veyon-master \
	simplon-veyon-configurator
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
printf 'Commandes disponibles: seven-control-lock, seven-control-import-inventory, seven-control-apply-profile, seven-control-validate-inventory, seven-control-health-check, seven-control-backup-config, seven-control-master, seven-control-configurator\n'
