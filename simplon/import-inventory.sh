#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf 'Usage: %s INVENTORY.csv [--veyon-cli PATH]\n' "$0" >&2
	exit "${1:-2}"
}

inventory_file=""
veyon_cli="${VEYON_CLI:-veyon-cli}"

while [ "$#" -gt 0 ]; do
	case "$1" in
		--veyon-cli)
			[ "$#" -ge 2 ] || usage
			veyon_cli="$2"
			shift 2
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

"$veyon_cli" networkobjects import "$tmp_file" format '%location%;%name%;%host%;%mac%'
printf 'Inventaire importe: %s\n' "$inventory_file"
