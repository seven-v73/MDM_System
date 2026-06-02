#!/usr/bin/env bash
set -euo pipefail

if ! command -v pacman >/dev/null 2>&1; then
	printf 'pacman est introuvable. Ce script cible Arch Linux / sevenOS base Arch.\n' >&2
	exit 1
fi

sudo_cmd=()
if [ "$(id -u)" -ne 0 ]; then
	sudo_cmd=(sudo)
fi

packages=(
	git
	base-devel
	cmake
	ninja
	pkgconf
	qt6-base
	qt6-5compat
	qt6-tools
	qt6-httpserver
	qca-qt6
	openssl
	libvncserver
	libfakekey
	libjpeg-turbo
	zlib
	lzo
	pam
	libldap
	cyrus-sasl
	procps-ng
	libx11
	libxext
	libxtst
	libxrandr
	libxinerama
	libxcursor
	libxdamage
	libxcomposite
	libxfixes
	libxkbcommon
	libxcb
	xcb-util-cursor
	libglvnd
	networkmanager
	gpsd
)

"${sudo_cmd[@]}" pacman -S --needed "${packages[@]}"

printf 'Dependances Arch/sevenOS installees.\n'
