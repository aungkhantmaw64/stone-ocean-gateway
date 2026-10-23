SUMMARY = "Stone Ocean gateway image"
DESCRIPTION = "Minimal headless image: SSH, BlueZ and bluetooth-meshd on a \
USB BLE dongle, to provision and talk to Stone Ocean mesh nodes."
LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "ssh-server-openssh"

# Bench development only: root logs in over SSH and serial with no
# password. Drop these before the gateway leaves the bench.
IMAGE_FEATURES += "allow-empty-password allow-root-login empty-root-password"

IMAGE_INSTALL = " \
    packagegroup-core-boot \
    packagegroup-stone-ocean-gateway \
    ${CORE_IMAGE_EXTRA_INSTALL} \
"

IMAGE_LINGUAS = ""
