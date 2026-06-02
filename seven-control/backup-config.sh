#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
Usage: backup-config.sh [--output-dir DIR] [--sudo] [--veyon-cli PATH]

Sauvegarde:
  - la configuration systeme Veyon en JSON;
  - les objets reseau integres en CSV;
  - un resume horodate.
EOF
	exit "${1:-2}"
}

output_dir="seven-control/backups"
veyon_cli="${VEYON_CLI:-veyon-cli}"
use_sudo="no"

while [ "$#" -gt 0 ]; do
	case "$1" in
		--output-dir)
			[ "$#" -ge 2 ] || usage
			output_dir="$2"
			shift 2
			;;
		--sudo)
			use_sudo="yes"
			shift
			;;
		--veyon-cli)
			[ "$#" -ge 2 ] || usage
			veyon_cli="$2"
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

mkdir -p "$output_dir"
timestamp="$(date +%Y%m%d-%H%M%S)"
config_file="$output_dir/veyon-config-$timestamp.json"
networkobjects_file="$output_dir/networkobjects-$timestamp.csv"
summary_file="$output_dir/summary-$timestamp.txt"

veyon_command=("$veyon_cli")
if [ "$use_sudo" = "yes" ] && [ "$(id -u)" -ne 0 ]; then
	veyon_command=(sudo env -u DISPLAY QT_QPA_PLATFORM=offscreen "$veyon_cli")
fi

"${veyon_command[@]}" config export "$config_file" >/dev/null
"${veyon_command[@]}" networkobjects export "$networkobjects_file" format '%location%;%name%;%host%;%mac%' >/dev/null

{
	printf 'Sauvegarde Seven Control Veyon\n'
	printf 'Date: %s\n' "$(date -Is)"
	printf 'Configuration: %s\n' "$config_file"
	printf 'Network objects: %s\n' "$networkobjects_file"
	printf 'Machines: %s\n' "$(grep -cve '^[[:space:]]*$' "$networkobjects_file" || true)"
} > "$summary_file"

printf 'Sauvegarde creee:\n'
printf '  %s\n' "$config_file"
printf '  %s\n' "$networkobjects_file"
printf '  %s\n' "$summary_file"
