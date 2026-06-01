#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
Usage:
  simplon-lock.sh lock --location LOCATION [--veyon-cli PATH]
  simplon-lock.sh unlock --location LOCATION [--veyon-cli PATH]
  simplon-lock.sh lock --hosts FILE [--veyon-cli PATH]
  simplon-lock.sh unlock --hosts FILE [--veyon-cli PATH]

Actions:
  lock      Demarre la fonctionnalite ScreenLock.
  unlock    Arrete la fonctionnalite ScreenLock.
EOF
	exit "${1:-2}"
}

[ "$#" -ge 1 ] || usage

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	usage 0
fi

action="$1"
shift

case "$action" in
	lock)
		feature_command="start"
		;;
	unlock)
		feature_command="stop"
		;;
	*)
		usage
		;;
esac

location=""
hosts_file=""
veyon_cli="${VEYON_CLI:-veyon-cli}"

while [ "$#" -gt 0 ]; do
	case "$1" in
		--location)
			[ "$#" -ge 2 ] || usage
			location="$2"
			shift 2
			;;
		--hosts)
			[ "$#" -ge 2 ] || usage
			hosts_file="$2"
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
			usage
			;;
	esac
done

if [ -n "$location" ] && [ -n "$hosts_file" ]; then
	printf 'Choisissez --location ou --hosts, pas les deux.\n' >&2
	exit 2
fi

if [ -z "$location" ] && [ -z "$hosts_file" ]; then
	printf 'Indiquez une location ou un fichier de hosts.\n' >&2
	exit 2
fi

tmp_hosts=""
if [ -n "$location" ]; then
	tmp_hosts="$(mktemp)"
	trap 'rm -f "$tmp_hosts"' EXIT
	"$veyon_cli" networkobjects export "$tmp_hosts" location "$location" format '%host%'
	hosts_file="$tmp_hosts"
fi

[ -f "$hosts_file" ] || {
	printf 'Fichier de machines introuvable: %s\n' "$hosts_file" >&2
	exit 1
}

status=0
while IFS= read -r host || [ -n "$host" ]; do
	host="${host%%#*}"
	host="$(printf '%s' "$host" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
	[ -n "$host" ] || continue

	printf '%s %s... ' "$action" "$host"
	if "$veyon_cli" feature "$feature_command" "$host" ScreenLock >/dev/null; then
		printf 'OK\n'
	else
		printf 'ECHEC\n'
		status=1
	fi
done < "$hosts_file"

exit "$status"
