#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
Usage:
  health-check.sh [--location LOCATION | --hosts FILE] [--port PORT] [--timeout SECONDS] [--parallel N]

Verifie l'environnement Seven Control/Veyon et, si des machines sont fournies,
teste la joignabilite TCP du port Veyon.
EOF
	exit "${1:-2}"
}

location=""
hosts_file=""
port=""
connect_timeout=2
parallel_jobs=32
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
		--parallel)
			[ "$#" -ge 2 ] || usage
			parallel_jobs="$2"
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

status=0
check_ok() { printf '[OK] %s\n' "$1"; }
check_fail() { printf '[FAIL] %s\n' "$1"; status=1; }
check_warn() { printf '[WARN] %s\n' "$1"; }

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
validate_positive_integer "--parallel" "$parallel_jobs"

if command -v "$veyon_cli" >/dev/null 2>&1; then
	check_ok "veyon-cli disponible: $(command -v "$veyon_cli")"
else
	check_fail "veyon-cli introuvable"
fi

if command -v seven-control-configurator >/dev/null 2>&1; then
	if seven-control-configurator --version 2>/dev/null | grep -q 'admin-wayland'; then
		check_ok "wrapper configurateur Seven Control installe"
	else
		check_warn "wrapper configurateur installe mais version inattendue"
	fi
else
	check_warn "seven-control-configurator introuvable"
fi

if command -v systemctl >/dev/null 2>&1; then
	if systemctl is-active --quiet veyon.service; then
		check_ok "veyon.service actif"
	else
		check_warn "veyon.service non actif sur cette machine"
	fi
fi

if [ -z "$port" ] && command -v "$veyon_cli" >/dev/null 2>&1; then
	port="$("$veyon_cli" config get Network/VeyonServerPort 2>/dev/null || true)"
fi
port="${port:-11100}"

tmp_hosts=""
if [ -n "$location" ]; then
	tmp_hosts="$(mktemp)"
	trap 'rm -f "$tmp_hosts"' EXIT
	if "$veyon_cli" networkobjects export "$tmp_hosts" location "$location" format '%host%' >/dev/null; then
		hosts_file="$tmp_hosts"
	else
		check_fail "location introuvable ou export impossible: $location"
	fi
fi

if [ -n "$hosts_file" ]; then
	[ -f "$hosts_file" ] || {
		check_fail "fichier hosts introuvable: $hosts_file"
		exit "$status"
	}

	tmp_status="$(mktemp -d)"
	trap 'rm -rf "$tmp_status" ${tmp_hosts:+"$tmp_hosts"}' EXIT

	check_host() {
		local host="$1"
		local status_file="$2"

		if timeout "$connect_timeout" bash -c ":</dev/tcp/$host/$port" 2>/dev/null; then
			printf '[OK] %s:%s joignable\n' "$host" "$port"
			printf '1\n' > "$status_file"
		else
			printf '[FAIL] %s:%s injoignable\n' "$host" "$port"
			printf '0\n' > "$status_file"
		fi
	}

	total=0
	active_jobs=0
	while IFS= read -r host || [ -n "$host" ]; do
		host="${host%%#*}"
		host="$(printf '%s' "$host" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		[ -n "$host" ] || continue
		total=$((total + 1))

		check_host "$host" "$tmp_status/$total" &
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

	online=0
	for status_file in "$tmp_status"/*; do
		if [ "$(cat "$status_file")" = "1" ]; then
			online=$((online + 1))
		fi
	done
	if [ "$online" -ne "$total" ]; then
		status=1
	fi
	printf 'Joignabilite: %d/%d machines accessibles sur le port %s\n' "$online" "$total" "$port"
fi

exit "$status"
