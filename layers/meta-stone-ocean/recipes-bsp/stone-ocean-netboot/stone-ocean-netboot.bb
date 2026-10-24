SUMMARY = "U-Boot script that boots the gateway over the network"
DESCRIPTION = "Dev builds only: boot.scr fetches the kernel and device tree \
over TFTP and mounts the root filesystem over NFS from the host running \
scripts/netboot.sh. netboot.txt next to it names that host."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://boot.cmd"
S = "${UNPACKDIR}"
B = "${WORKDIR}/build"

DEPENDS = "u-boot-tools-native"
inherit deploy kernel-arch nopackages

# Uses the machine's kernel image type and serial console.
PACKAGE_ARCH = "${MACHINE_ARCH}"

# Must match the export and ports in scripts/netboot.sh.
NETBOOT_NFS_EXPORT = "/srv/nfsroot"
NETBOOT_NFS_PORT = "3049"
NETBOOT_MOUNT_PORT = "3048"

# "115200;ttyS0" (first SERIAL_CONSOLES entry) -> "ttyS0,115200".
NETBOOT_CONSOLE ?= "${@','.join(reversed(d.getVar('SERIAL_CONSOLES').split()[0].split(';')))}"
NETBOOT_BOOTCMD ?= "${@ {'zImage': 'bootz', 'Image': 'booti'}.get(d.getVar('KERNEL_IMAGETYPE'), 'bootm')}"

do_compile() {
	if [ -z "${STONE_OCEAN_NETBOOT_SERVER}" ]; then
		bbfatal "STONE_OCEAN_NETBOOT_SERVER is empty; build with scripts/build.sh --dev"
	fi
	sed -e 's|@KERNEL_IMAGETYPE@|${KERNEL_IMAGETYPE}|' \
	    -e 's|@BOOTCMD@|${NETBOOT_BOOTCMD}|' \
	    -e 's|@CONSOLE@|${NETBOOT_CONSOLE}|' \
	    -e 's|@NFS_EXPORT@|${NETBOOT_NFS_EXPORT}|' \
	    -e 's|@NFS_PORT@|${NETBOOT_NFS_PORT}|' \
	    -e 's|@MOUNT_PORT@|${NETBOOT_MOUNT_PORT}|' \
	    ${S}/boot.cmd > ${B}/boot.cmd
	uboot-mkimage -A ${UBOOT_ARCH} -T script -C none -n "Stone Ocean netboot" \
		-d ${B}/boot.cmd ${B}/boot.scr
	echo "netboot_server=${STONE_OCEAN_NETBOOT_SERVER}" > ${B}/netboot.txt
}

do_deploy() {
	install -m 0644 ${B}/boot.scr ${B}/netboot.txt ${DEPLOYDIR}/
}
addtask deploy after do_compile before do_build
