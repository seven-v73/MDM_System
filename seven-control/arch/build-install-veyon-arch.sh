#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
Usage: build-install-veyon-arch.sh [options]

Options:
  --build-dir DIR       Repertoire de build (defaut: build-arch)
  --prefix DIR          Prefixe d'installation (defaut: /usr)
  --translations        Active la generation des traductions
  --webapi              Active le plugin WebAPI
  --no-install          Compile seulement, sans installation systeme
  -h, --help            Affiche cette aide
EOF
	exit "${1:-2}"
}

build_dir="build-arch"
prefix="/usr"
translations="OFF"
webapi="OFF"
install_after_build="yes"

while [ "$#" -gt 0 ]; do
	case "$1" in
		--build-dir)
			[ "$#" -ge 2 ] || usage
			build_dir="$2"
			shift 2
			;;
		--prefix)
			[ "$#" -ge 2 ] || usage
			prefix="$2"
			shift 2
			;;
		--translations)
			translations="ON"
			shift
			;;
		--webapi)
			webapi="ON"
			shift
			;;
		--no-install)
			install_after_build="no"
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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

if ! command -v cmake >/dev/null 2>&1 || ! command -v ninja >/dev/null 2>&1; then
	printf "cmake ou ninja est introuvable. Lancez ./seven-control/arch/install-deps-arch.sh d'abord.\n" >&2
	exit 1
fi

git submodule update --init --recursive

cmake -S . -B "$build_dir" -G Ninja \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DCMAKE_INSTALL_PREFIX="$prefix" \
	-DSYSTEMD_SERVICE_INSTALL_DIR=/usr/lib/systemd/system \
	-DWITH_QT6=ON \
	-DWITH_TRANSLATIONS="$translations" \
	-DWITH_WEBAPI="$webapi" \
	-DWITH_LTO=OFF

cmake --build "$build_dir"

if [ "$install_after_build" = "yes" ]; then
	if [ "$(id -u)" -eq 0 ]; then
		cmake --install "$build_dir"
	else
		sudo cmake --install "$build_dir"
	fi
	printf 'Veyon installe dans %s.\n' "$prefix"
else
	printf 'Build termine dans %s. Installation ignoree.\n' "$build_dir"
fi
