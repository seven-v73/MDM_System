#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf 'Usage: %s INVENTORY.csv\n' "$0" >&2
	exit "${1:-2}"
}

[ "$#" -eq 1 ] || usage
inventory_file="$1"

[ -f "$inventory_file" ] || {
	printf 'Inventaire introuvable: %s\n' "$inventory_file" >&2
	exit 1
}

awk -F';' '
BEGIN {
	status = 0
}
NR == 1 {
	gsub(/\r$/, "", $0)
	if ($0 == "location;name;host;mac") {
		next
	}
}
{
	gsub(/\r$/, "", $0)
	if ($0 ~ /^[[:space:]]*$/) {
		next
	}
	if (NF != 4) {
		printf "Ligne %d: 4 colonnes attendues, %d trouvees\n", NR, NF > "/dev/stderr"
		status = 1
		next
	}
	for (i = 1; i <= 3; i++) {
		gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
	}
	if ($1 == "" || $2 == "" || $3 == "") {
		printf "Ligne %d: location, name et host sont obligatoires\n", NR > "/dev/stderr"
		status = 1
	}
	hostKey = tolower($3)
	nameKey = tolower($1 "/" $2)
	if (hostKey in hosts) {
		printf "Ligne %d: host duplique avec la ligne %d: %s\n", NR, hosts[hostKey], $3 > "/dev/stderr"
		status = 1
	} else {
		hosts[hostKey] = NR
	}
	if (nameKey in names) {
		printf "Ligne %d: nom duplique dans la meme location avec la ligne %d: %s/%s\n", NR, names[nameKey], $1, $2 > "/dev/stderr"
		status = 1
	} else {
		names[nameKey] = NR
	}
	count++
}
END {
	if (count == 0) {
		print "Inventaire vide" > "/dev/stderr"
		status = 1
	}
	if (status == 0) {
		printf "Inventaire valide: %d machines\n", count
	}
	exit status
}
' "$inventory_file"
