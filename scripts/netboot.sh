#!/bin/sh
# Serve a dev build to the board from a container: kernel and device tree
# over TFTP, root filesystem over NFS.
#
#   scripts/netboot.sh [BOARD] start|stop|status|logs|rootfs|modules|clean
#
# Build first with scripts/build.sh --dev BOARD and flash its SD card once.
# TFTP serves the build's deploy directory as it is, so a rebuilt kernel is
# picked up on the next boot. The root filesystem is unpacked once into
# build/<BOARD>-dev/nfsroot:
#
#   rootfs   unpack the image's root filesystem again (loses all state on it)
#   modules  replace only the kernel modules, after a kernel rebuild
#   clean    stop and delete the nfsroot (its files are root-owned)
#
# Nothing on the host is configured. The container uses the host network:
# TFTP on udp/69, NFS on tcp/3049 and mount on tcp/3048, no portmapper. A host
# firewall must let those in.
set -eu

top=$(cd "$(dirname "$0")/.." && pwd)
board=beaglebone-black
case ${1:-} in
start | stop | status | logs | rootfs | modules | clean | "") ;;
*)
	board=$1
	shift
	;;
esac
cmd=${1:-start}

board_file=$top/kas/boards/$board.yml
if [ ! -f "$board_file" ]; then
	echo "unknown board '$board'; available:" >&2
	ls "$top/kas/boards" | sed -n 's/\.yml$//p' | grep -v '\.lock$' >&2
	exit 2
fi
machine=$(sed -n 's/^machine: *//p' "$board_file")

dev_dir=$top/build/$board-dev
deploy=$dev_dir/tmp/deploy/images/$machine
rootfs_tar=stone-ocean-gateway-image-$machine.rootfs.tar.zst
modules_tgz=modules-$machine.tgz
name=stone-ocean-netboot-$board

image=stone-ocean-netboot:$(cat "$top/scripts/netboot/Dockerfile" "$top/scripts/netboot/serve.sh" | sha256sum | cut -c1-12)
if ! docker image inspect "$image" >/dev/null 2>&1; then
	docker build -q -t "$image" "$top/scripts/netboot" >/dev/null
fi

# Runs a shell command as root in a throw-away container, with the deploy
# directory at /srv/tftp and build/<board>-dev at /work. Only existing
# directories are mounted; docker would create missing ones root-owned.
tool() {
	if [ -d "$deploy" ]; then
		docker run --rm -v "$dev_dir:/work" -v "$deploy:/srv/tftp:ro" "$image" sh -euc "$1"
	else
		docker run --rm -v "$dev_dir:/work" "$image" sh -euc "$1"
	fi
}

need_build() {
	if [ ! -e "$deploy/$1" ]; then
		echo "no $1 in $deploy; run scripts/build.sh --dev $board" >&2
		exit 1
	fi
}

unpack_rootfs() {
	need_build "$rootfs_tar"
	echo "unpacking $rootfs_tar into build/$board-dev/nfsroot"
	tool "rm -rf /work/nfsroot && mkdir /work/nfsroot &&
		tar --zstd --numeric-owner --xattrs --xattrs-include='*' -xpf /srv/tftp/$rootfs_tar -C /work/nfsroot"
}

running() {
	[ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null)" = true ]
}

case $cmd in
start)
	need_build zImage
	[ -d "$dev_dir/nfsroot/etc" ] || unpack_rootfs
	if running; then
		echo "$name is already running"
		exit 0
	fi
	docker rm -f "$name" >/dev/null 2>&1 || true
	docker run -d --init --name "$name" --network host \
		-v "$deploy:/srv/tftp:ro" -v "$dev_dir/nfsroot:/srv/nfsroot" \
		"$image" >/dev/null
	server=$(sed -n 's/^netboot_server=//p' "$deploy/netboot.txt" 2>/dev/null || true)
	echo "serving $board: TFTP udp/69, NFS tcp/3049, mount tcp/3048"
	echo "the SD card's netboot.txt points the board at ${server:-?}"
	;;
stop)
	docker rm -f "$name" >/dev/null 2>&1 || true
	;;
status)
	if running; then echo "$name is running"; else echo "$name is stopped"; exit 1; fi
	;;
logs)
	exec docker logs -f "$name"
	;;
rootfs)
	printf 'This deletes everything on the NFS root, including mesh keys. Continue? [y/N] '
	read -r answer
	[ "$answer" = y ] || exit 1
	unpack_rootfs
	;;
modules)
	need_build "$modules_tgz"
	[ -d "$dev_dir/nfsroot/etc" ] || { echo "no nfsroot yet; run start" >&2; exit 1; }
	# The rootfs has a merged /usr (lib -> usr/lib): keep that symlink, drop
	# the old modules of each kernel version in the tarball, then rebuild
	# modules.dep, which the tarball does not carry.
	tool "cd /work/nfsroot &&
		vers=\$(tar -tzf /srv/tftp/$modules_tgz | sed -n 's|^lib/modules/\\([^/]*\\)/\$|\\1|p') &&
		for v in \$vers; do rm -rf lib/modules/\$v; done &&
		tar --keep-directory-symlink -xzf /srv/tftp/$modules_tgz &&
		for v in \$vers; do depmod -b /work/nfsroot \$v; echo \"modules for \$v updated\"; done"
	;;
clean)
	docker rm -f "$name" >/dev/null 2>&1 || true
	if [ -d "$dev_dir" ]; then
		tool "rm -rf /work/nfsroot"
	fi
	;;
*)
	echo "unknown command '$cmd'" >&2
	exit 2
	;;
esac
