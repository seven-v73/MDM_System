#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf 'Usage: %s INVENTORY.csv [--sudo] [--veyon-cli PATH]\n' "$0" >&2
	exit "${1:-2}"
}

inventory_file=""
veyon_cli="${VEYON_CLI:-veyon-cli}"
use_sudo="no"

while [ "$#" -gt 0 ]; do
	case "$1" in
		--veyon-cli)
			[ "$#" -ge 2 ] || usage
			veyon_cli="$2"
			shift 2
			;;
		--sudo)
			use_sudo="yes"
			shift
			;;
		-h|--help)
			usage 0
			;;
		*)
			if [ -n "$inventory_file" ]; then
				usage
			fi
			inventory_file="$1"
			shift
			;;
	esac
done

[ -n "$inventory_file" ] || usage
[ -f "$inventory_file" ] || {
	printf 'Inventaire introuvable: %s\n' "$inventory_file" >&2
	exit 1
}

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

# Veyon attend directement les lignes de donnees. On retire donc l'en-tete si present.
awk 'NR == 1 && $0 ~ /^location;name;host;mac\r?$/ { next } NF { print }' "$inventory_file" > "$tmp_file"

veyon_command=("$veyon_cli")
if [ "$use_sudo" = "yes" ] && [ "$(id -u)" -ne 0 ]; then
	veyon_command=(sudo env -u DISPLAY QT_QPA_PLATFORM=offscreen "$veyon_cli")
fi

set +e
"${veyon_command[@]}" networkobjects import "$tmp_file" format '%location%;%name%;%host%;%mac%'
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
	printf 'Import impossible avec les droits actuels.\n' >&2
	printf 'Veyon ecrit les objets reseau dans la configuration systeme.\n' >&2
	printf 'Relancez avec: %s %s --sudo\n' "$0" "$inventory_file" >&2
	exit "$rc"
fi

printf 'Inventaire importe: %s\n' "$inventory_file"
