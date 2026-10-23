SUMMARY = "Network settings for the Stone Ocean gateway"
DESCRIPTION = "Answers mDNS on wired links, so the gateway is reachable as \
<hostname>.local without knowing its DHCP address."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://resolved-mdns.conf \
    file://wired-mdns.conf \
"
S = "${UNPACKDIR}"

inherit allarch features_check
REQUIRED_DISTRO_FEATURES = "systemd"

do_install() {
	# Drop-ins for systemd-resolved and for systemd-conf's 80-wired.network.
	install -D -m 0644 ${S}/resolved-mdns.conf ${D}${sysconfdir}/systemd/resolved.conf.d/mdns.conf
	install -D -m 0644 ${S}/wired-mdns.conf ${D}${sysconfdir}/systemd/network/80-wired.network.d/mdns.conf
}

RDEPENDS:${PN} = "systemd systemd-conf"
