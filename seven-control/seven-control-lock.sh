#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
Usage:
  seven-control-lock.sh lock --location LOCATION [options]
  seven-control-lock.sh unlock --location LOCATION [options]
  seven-control-lock.sh lock --hosts FILE [options]
  seven-control-lock.sh unlock --hosts FILE [options]

Actions:
  lock      Demarre la fonctionnalite ScreenLock.
  unlock    Arrete la fonctionnalite ScreenLock.

Options:
  --parallel N          Nombre d'actions simultanees (defaut: 8)
  --timeout SECONDS     Timeout par machine (defaut: 45)
  --retries N           Tentatives supplementaires par machine (defaut: 0)
  --retry-delay SEC     Delai entre tentatives (defaut: 2)
  --dry-run             Affiche les machines sans agir
  --log-file FILE       Journal CSV des actions
  --veyon-cli PATH      Chemin vers veyon-cli
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
parallel_jobs=8
command_timeout=45
retries=0
retry_delay=2
dry_run="no"
log_file=""

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
		--parallel)
			[ "$#" -ge 2 ] || usage
			parallel_jobs="$2"
			shift 2
			;;
		--timeout)
			[ "$#" -ge 2 ] || usage
			command_timeout="$2"
			shift 2
			;;
		--retries)
			[ "$#" -ge 2 ] || usage
			retries="$2"
			shift 2
			;;
		--retry-delay)
			[ "$#" -ge 2 ] || usage
			retry_delay="$2"
			shift 2
			;;
		--dry-run)
			dry_run="yes"
			shift
			;;
		--log-file)
			[ "$#" -ge 2 ] || usage
			log_file="$2"
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

case "$parallel_jobs" in
	''|*[!0-9]*)
		printf 'La valeur --parallel doit etre un entier positif.\n' >&2
		exit 2
		;;
esac

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

validate_positive_integer "--parallel" "$parallel_jobs"
validate_positive_integer "--timeout" "$command_timeout"
validate_positive_integer "--retries" "$retries"
validate_positive_integer "--retry-delay" "$retry_delay"

if [ "$parallel_jobs" -lt 1 ] || [ "$command_timeout" -lt 1 ]; then
	printf '--parallel et --timeout doivent etre superieurs ou egaux a 1.\n' >&2
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

tmp_status="$(mktemp -d)"
trap 'rm -rf "$tmp_status" ${tmp_hosts:+"$tmp_hosts"}' EXIT

if [ -n "$log_file" ]; then
	printf 'timestamp,action,host,result,attempts\n' > "$log_file"
fi

append_log() {
	local host="$1"
	local result="$2"
	local attempts="$3"

	if [ -n "$log_file" ]; then
		printf '%s,%s,%s,%s,%s\n' "$(date -Is)" "$action" "$host" "$result" "$attempts" >> "$log_file"
	fi
}

run_host() {
	local host="$1"
	local status_file="$2"
	local attempt=0
	local max_attempts=$((retries + 1))

	if [ "$dry_run" = "yes" ]; then
		printf '%s %s... DRY-RUN\n' "$action" "$host"
		append_log "$host" "DRY-RUN" 0
		printf '0\n' > "$status_file"
		return
	fi

	while [ "$attempt" -lt "$max_attempts" ]; do
		attempt=$((attempt + 1))
		if timeout "$command_timeout" "$veyon_cli" feature "$feature_command" "$host" ScreenLock >/dev/null; then
			printf '%s %s... OK (tentative %d/%d)\n' "$action" "$host" "$attempt" "$max_attempts"
			append_log "$host" "OK" "$attempt"
			printf '0\n' > "$status_file"
			return
		fi

		if [ "$attempt" -lt "$max_attempts" ]; then
			sleep "$retry_delay"
		fi
	done

	printf '%s %s... ECHEC (%d tentative(s))\n' "$action" "$host" "$max_attempts"
	append_log "$host" "ECHEC" "$max_attempts"
	printf '1\n' > "$status_file"
}

status=0
active_jobs=0
host_index=0
while IFS= read -r host || [ -n "$host" ]; do
	host="${host%%#*}"
	host="$(printf '%s' "$host" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
	[ -n "$host" ] || continue

	host_index=$((host_index + 1))
	run_host "$host" "$tmp_status/$host_index" &
	active_jobs=$((active_jobs + 1))

	if [ "$active_jobs" -ge "$parallel_jobs" ]; then
		wait -n || true
		active_jobs=$((active_jobs - 1))
	fi
done < "$hosts_file"

while [ "$active_jobs" -gt 0 ]; do
	wait -n || true
	active_jobs=$((active_jobs - 1))
done

if [ "$host_index" -eq 0 ]; then
	printf 'Aucune machine cible trouvee.\n' >&2
	exit 1
fi

for status_file in "$tmp_status"/*; do
	if [ "$(cat "$status_file")" != "0" ]; then
		status=1
	fi
done

exit "$status"
