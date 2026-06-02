#!/usr/bin/env bash
set -euo pipefail

wrapper_version="2026-06-02-admin-wayland"
command_name="$(basename "$0")"
app="${1:-}"

if [ "$app" = "--version" ]; then
	printf 'seven-control-gui-wrapper %s\n' "$wrapper_version"
	exit 0
fi

if [ -z "$app" ]; then
	case "$command_name" in
		seven-control-master)
			app="veyon-master"
			;;
		seven-control-configurator)
			app="veyon-configurator"
			;;
		*)
			printf 'Usage: %s veyon-master|veyon-configurator\n' "$0" >&2
			exit 2
			;;
	esac
else
	shift
fi

case "$app" in
	veyon-master|veyon-configurator)
		;;
	*)
		printf 'Application Veyon non supportee: %s\n' "$app" >&2
		exit 2
		;;
esac

if [ -z "${QT_QPA_PLATFORM:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ]; then
	export QT_QPA_PLATFORM=wayland
fi

if [ "$app" = "veyon-configurator" ] && [ "$(id -u)" -ne 0 ]; then
	if [ "${SEVEN_CONTROL_CONFIGURATOR_NO_SUDO:-0}" != "1" ]; then
		if [ "${SEVEN_CONTROL_DEBUG:-0}" = "1" ]; then
			printf 'Seven Control wrapper %s: launching %s as admin with QT_QPA_PLATFORM=%s\n' \
				"$wrapper_version" "$app" "${QT_QPA_PLATFORM:-}" >&2
		fi

		if [ "${QT_QPA_PLATFORM:-}" = "wayland" ]; then
			exec sudo env \
				XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
				WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" \
				QT_QPA_PLATFORM=wayland \
				"$app" -elevated "$@"
		fi

		exec sudo env \
			DISPLAY="${DISPLAY:-}" \
			XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" \
			QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}" \
			"$app" -elevated "$@"
	fi
fi

exec "$app" "$@"
