#!/bin/sh
# Container entry point: TFTP from /srv/tftp, NFSv3 export of /srv/nfsroot.
# The ports must match NETBOOT_*_PORT in the stone-ocean-netboot recipe.
set -eu

echo '/srv/nfsroot (rw,no_root_squash,insecure)' > /etc/exports

# Standalone, foreground, chrooted into /srv/tftp.
in.tftpd -l -L -v -s /srv/tftp &
# -p: no portmapper; the kernel is given both ports in nfsroot=.
exec unfsd -d -p -t -n 3049 -m 3048 -e /etc/exports
