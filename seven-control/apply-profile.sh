#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
Usage: apply-profile.sh [--sudo] [--massive] [--veyon-cli PATH]

Applique le profil Seven Control de base:
  - annuaire reseau integre Veyon;
  - backend de groupes utilisateurs systeme;
  - intervalle de mise a jour annuaire a 60 secondes;
  - journalisation warnings/errors.

Option --massive:
  - reduit la qualite du monitoring;
  - espace les mises a jour miniatures;
  - active la rotation des logs;
  - evite les notifications de connexion sur les postes.
EOF
	exit "${1:-2}"
}

veyon_cli="${VEYON_CLI:-veyon-cli}"
use_sudo="no"
massive="no"

while [ "$#" -gt 0 ]; do
	case "$1" in
		--sudo)
			use_sudo="yes"
			shift
			;;
		--massive)
			massive="yes"
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

veyon_command=("$veyon_cli")
if [ "$use_sudo" = "yes" ] && [ "$(id -u)" -ne 0 ]; then
	veyon_command=(sudo env -u DISPLAY QT_QPA_PLATFORM=offscreen "$veyon_cli")
fi

run_config_set() {
	"${veyon_command[@]}" config set "$1" "$2"
}

run_config_set "NetworkObjectDirectory/Plugin" "14bacaaa-ebe5-449c-b881-5b382f952571"
run_config_set "NetworkObjectDirectory/UpdateInterval" "60"
run_config_set "UserGroups/Backend" "2917cdeb-ac13-4099-8715-20368254a367"
run_config_set "Logging/LogLevel" "1"

if [ "$massive" = "yes" ]; then
	run_config_set "Master/ComputerMonitoringUpdateInterval" "3000"
	run_config_set "Master/ComputerMonitoringImageQuality" "4"
	run_config_set "Service/RemoteConnectionNotifications" "false"
	run_config_set "Logging/LogFileSizeLimitEnabled" "true"
	run_config_set "Logging/LogFileRotationEnabled" "true"
	run_config_set "Logging/LogFileSizeLimit" "100"
	run_config_set "Logging/LogFileRotationCount" "10"
fi

printf 'Profil Seven Control applique.\n'
