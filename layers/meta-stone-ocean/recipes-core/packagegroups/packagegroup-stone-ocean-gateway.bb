SUMMARY = "Stone Ocean gateway: Bluetooth mesh over a USB BLE dongle"
LICENSE = "MIT"

# Kernel modules are machine-specific.
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

# bluez5 carries bluetooth-meshd and mesh-cfgclient (see its bbappend).
RDEPENDS:${PN} = " \
    bluez5 \
    stone-ocean-netconf \
    usbutils \
"

# The Bluetooth stack is built as modules (recipes-kernel/linux), so a
# machine that does not install all kernel modules still gets the USB
# driver. Firmware is for the Realtek chips in most cheap BLE 5 dongles
# (RTL8761B/BU, RTL8821C); CSR and Broadcom dongles need none.
RRECOMMENDS:${PN} = " \
    kernel-module-btusb \
    linux-firmware-rtl8761 \
    linux-firmware-rtl8821 \
"
