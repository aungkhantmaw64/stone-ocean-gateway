# Board-independent kernel options for the gateway, as config fragments.
# Any kernel recipe that merges fragments (kernel-yocto) can take them by
# requiring this file from its bbappend.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://bluetooth-usb.cfg \
    file://mesh-crypto.cfg \
"
