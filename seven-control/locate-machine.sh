#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
Usage:
  locate-machine.sh QUERY [--inventory FILE] [--port PORT] [--timeout SECONDS] [--veyon-cli PATH]

Recherche une machine par nom, IP, MAC ou salle et affiche sa localisation
operationnelle: location, nom, host, MAC et etat de joignabilite.

Sans --inventory, la commande lit l'annuaire reseau Veyon integre.
EOF
	exit "${1:-2}"
}

query=""
inventory_file=""
port=""
connect_timeout=2
veyon_cli="${VEYON_CLI:-veyon-cli}"

while [ "$#" -gt 0 ]; do
	case "$1" in
		--inventory)
			[ "$#" -ge 2 ] || usage
			inventory_file="$2"
			shift 2
			;;
		--port)
			[ "$#" -ge 2 ] || usage
			port="$2"
			shift 2
			;;
		--timeout)
			[ "$#" -ge 2 ] || usage
			connect_timeout="$2"
			shift 2
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
			if [ -n "$query" ]; then
				usage
			fi
			query="$1"
			shift
			;;
	esac
done

[ -n "$query" ] || usage

validate_positive_integer() {
	local name="$1"
	local value="$2"

	case "$value" in
		''|*[!0-9]*)
			printf 'La valeur %s doit etre un entier positif.\n' "$name" >&2
			exit 2
			;;
	esac
}

validate_positive_integer "--timeout" "$connect_timeout"

tmp_inventory=""
if [ -z "$inventory_file" ]; then
	command -v "$veyon_cli" >/dev/null 2>&1 || {
		printf 'veyon-cli introuvable. Utilisez --inventory FILE ou installez Veyon.\n' >&2
		exit 1
	}

	tmp_inventory="$(mktemp)"
	trap 'rm -f "$tmp_inventory"' EXIT
	if ! "$veyon_cli" networkobjects export "$tmp_inventory" format '%location%;%name%;%host%;%mac%' >/dev/null; then
		printf 'Export de l annuaire Veyon impossible. Essayez avec --inventory FILE.\n' >&2
		exit 1
	fi
	inventory_file="$tmp_inventory"
fi

[ -f "$inventory_file" ] || {
	printf 'Inventaire introuvable: %s\n' "$inventory_file" >&2
	exit 1
}

if [ -z "$port" ] && command -v "$veyon_cli" >/dev/null 2>&1; then
	port="$("$veyon_cli" config get Network/VeyonServerPort 2>/dev/null || true)"
fi
port="${port:-11100}"

matches="$(awk -F ';' -v q="$query" '
BEGIN {
	needle = tolower(q)
}
NR == 1 && $0 ~ /^location;name;host;mac\r?$/ {
	next
}
NF >= 4 {
	line = tolower($1 ";" $2 ";" $3 ";" $4)
	if (index(line, needle) > 0) {
		gsub(/\r$/, "", $4)
		print $1 ";" $2 ";" $3 ";" $4
	}
}
' "$inventory_file")"

if [ -z "$matches" ]; then
	printf 'Aucune machine trouvee pour: %s\n' "$query" >&2
	exit 1
fi

printf 'Recherche: %s\n' "$query"
printf 'Port teste: %s\n\n' "$port"
printf '%-24s %-24s %-22s %-20s %-12s\n' 'LOCATION' 'NOM' 'HOST' 'MAC' 'ETAT'

while IFS=';' read -r location name host mac; do
	[ -n "$host" ] || continue
	state="injoignable"
	if timeout "$connect_timeout" bash -c ":</dev/tcp/$host/$port" 2>/dev/null; then
		state="joignable"
	fi
	printf '%-24s %-24s %-22s %-20s %-12s\n' "$location" "$name" "$host" "$mac" "$state"
done <<EOF
$matches
EOF
