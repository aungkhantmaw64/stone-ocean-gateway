#!/bin/sh
# Build the gateway image for one board inside the kas container.
#
#   scripts/build.sh [BOARD] [kas command]
#
# BOARD names a file in kas/boards/ (default: beaglebone-black). The kas
# command defaults to "build"; "shell" opens a bitbake shell for the board,
# "lock" refreshes the board's pinned layer revisions.
#
# Only Docker (or Podman) is needed on the host. Everything lands in build/:
# downloads and sstate are shared between boards, the build directory is per
# board (build/<board>/tmp/deploy/images/ holds the images).
set -eu

KAS_VERSION=5.5
KAS_CONTAINER_SHA256=7a8186f18d14ec6bec3f8d5188eba7a60f1ef4b5587af15917527588cc7d738a

top=$(cd "$(dirname "$0")/.." && pwd)
board=${1:-beaglebone-black}
[ $# -gt 0 ] && shift
cmd=${1:-build}
[ $# -gt 0 ] && shift

board_file=kas/boards/$board.yml
if [ ! -f "$top/$board_file" ]; then
	echo "unknown board '$board'; available:" >&2
	ls "$top/kas/boards" | sed -n 's/\.yml$//p' | grep -v '\.lock$' >&2
	exit 2
fi

kas_container=$top/build/kas-container-$KAS_VERSION
if [ ! -x "$kas_container" ]; then
	mkdir -p "$top/build"
	curl -sSfL -o "$kas_container.tmp" \
		"https://raw.githubusercontent.com/siemens/kas/$KAS_VERSION/kas-container"
	echo "$KAS_CONTAINER_SHA256  $kas_container.tmp" | sha256sum -c --quiet
	chmod +x "$kas_container.tmp"
	mv "$kas_container.tmp" "$kas_container"
fi

export KAS_WORK_DIR="$top/build/layers"
export KAS_BUILD_DIR="$top/build/$board"
export DL_DIR="$top/build/downloads"
export SSTATE_DIR="$top/build/sstate-cache"
mkdir -p "$KAS_WORK_DIR" "$KAS_BUILD_DIR"

cd "$top"
exec "$kas_container" "$cmd" "$@" "$board_file"
