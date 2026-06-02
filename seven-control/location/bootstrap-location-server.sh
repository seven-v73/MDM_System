#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
Usage:
  bootstrap-location-server.sh [--config FILE] [--bind HOST] [--port PORT] [--data-dir DIR] [--retention-days DAYS] [--force]

Cree une configuration serveur Seven Control Location avec tokens forts.
Par defaut: /etc/seven-control/location-server.env
EOF
	exit "${1:-2}"
}

config_file="/etc/seven-control/location-server.env"
bind_host="127.0.0.1"
port="8765"
data_dir="/var/lib/seven-control-location"
retention_days="30"
force="no"

while [ "$#" -gt 0 ]; do
	case "$1" in
		--config)
			[ "$#" -ge 2 ] || usage
			config_file="$2"
			shift 2
			;;
		--bind)
			[ "$#" -ge 2 ] || usage
			bind_host="$2"
			shift 2
			;;
		--port)
			[ "$#" -ge 2 ] || usage
			port="$2"
			shift 2
			;;
		--data-dir)
			[ "$#" -ge 2 ] || usage
			data_dir="$2"
			shift 2
			;;
		--retention-days)
			[ "$#" -ge 2 ] || usage
			retention_days="$2"
			shift 2
			;;
		--force)
			force="yes"
			shift
			;;
		-h|--help)
			usage 0
			;;
		*)
			usage
			;;
	esac
done

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

validate_positive_integer "--port" "$port"
validate_positive_integer "--retention-days" "$retention_days"

if [ -e "$config_file" ] && [ "$force" != "yes" ]; then
	printf 'Configuration deja presente: %s\n' "$config_file" >&2
	printf 'Relancez avec --force pour la remplacer.\n' >&2
	exit 1
fi

generate_token() {
	if command -v seven-control-location-admin >/dev/null 2>&1; then
		seven-control-location-admin generate-token --bytes 32
	else
		python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(32))
PY
	fi
}

enroll_token="$(generate_token)"
admin_token="$(generate_token)"
config_dir="$(dirname "$config_file")"

if [ "$(id -u)" -ne 0 ] && [ "${config_file#/etc/}" != "$config_file" ]; then
	printf 'Ce chemin necessite les droits admin: %s\n' "$config_file" >&2
	printf 'Relancez avec sudo ou utilisez --config dans un dossier accessible.\n' >&2
	exit 1
fi

if [ ! -d "$config_dir" ]; then
	install -d -m 0750 "$config_dir"
fi
umask 077
cat > "$config_file" <<EOF
SEVEN_CONTROL_LOCATION_BIND=$bind_host
SEVEN_CONTROL_LOCATION_PORT=$port
SEVEN_CONTROL_LOCATION_DATA_DIR=$data_dir
SEVEN_CONTROL_LOCATION_TOKEN=$enroll_token
SEVEN_CONTROL_LOCATION_ADMIN_TOKEN=$admin_token
SEVEN_CONTROL_LOCATION_RETENTION_DAYS=$retention_days
EOF
chmod 0600 "$config_file"

printf 'Configuration serveur creee: %s\n' "$config_file"
printf '\n'
printf 'Token enrolement agents:\n%s\n' "$enroll_token"
printf '\n'
printf 'Token admin:\n%s\n' "$admin_token"
printf '\n'
printf 'Conservez ces tokens dans un coffre de secrets.\n'
printf 'Demarrage Linux/systemd:\n'
printf '  sudo systemctl daemon-reload\n'
printf '  sudo systemctl enable --now seven-control-location-server.service\n'
