# The gateway uses Bluetooth only for the mesh. Build bluetooth-meshd and
# mesh-cfgclient, and drop the audio, OBEX and input profiles.
PACKAGECONFIG = " \
    ${@bb.utils.filter('DISTRO_FEATURES', 'systemd', d)} \
    deprecated \
    mesh \
    readline \
    tools \
    udev \
"

# bluetooth-meshd needs exclusive use of its adapter, so it starts in place
# of bluetoothd. Its unit is WantedBy=bluetooth.target, which udev pulls in
# when the dongle appears.
SYSTEMD_SERVICE:${PN} = "bluetooth-mesh.service"
