# Stone Ocean Gateway

Embedded Linux gateway for the [Stone Ocean](../stone-ocean) BLE mesh nodes.
It is a Yocto image that runs BlueZ `bluetooth-meshd` on a USB BLE dongle
and can be reached over SSH. With it you can provision and configure the
nodes (`mesh-cfgclient` now, the spec 12 gateway tool later) without a
Bluetooth-capable development PC.

| | |
|---|---|
| Yocto | 6.0 "wrynose" (LTS): OE-core, meta-poky, bitbake 2.18 |
| Build tool | [kas](https://kas.readthedocs.io) 5.5, run in its container |
| Boards | BeagleBone Black (`beaglebone-black`) |
| BlueZ | 5.86, with `bluetooth-meshd` and `mesh-cfgclient` |
| Init | systemd, networkd (DHCP on Ethernet), resolved (mDNS) |

## What is in the image

- **SSH:** OpenSSH. Root logs in **with no password** over SSH and the serial
  console. This is for bench development only; see `IMAGE_FEATURES` in the
  image recipe.
- **Network:** DHCP on Ethernet. The hostname is `stone-ocean-gw` and it
  answers mDNS, so `ssh root@stone-ocean-gw.local` works on the same LAN.
- **Bluetooth:** kernel Bluetooth and `btusb` as modules, firmware for
  Realtek RTL8761B/BU and RTL8821C dongles. CSR8510 and Broadcom dongles need
  no firmware.
- **Mesh:** `bluetooth-meshd` starts as soon as a dongle is plugged in. It
  needs the adapter to itself, so `bluetoothd` is installed but not started.
  The kernel is built with the AF_ALG crypto sockets that `bluetooth-meshd`
  needs (`algif_aead`, `algif_hash`, `algif_skcipher`).
- **Tools:** `mesh-cfgclient`, `btmon`, `bluetoothctl`, `hciconfig`, `lsusb`.

## Building

Only Docker (or Podman) and about 60 GB of disk are needed on the host. The
first build takes about an hour on 20 cores and downloads several GB.

```sh
scripts/build.sh                      # same as: scripts/build.sh beaglebone-black
scripts/build.sh beaglebone-black shell   # bitbake shell, e.g. bitbake -c menuconfig virtual/kernel
scripts/build.sh beaglebone-black lock    # move the pinned layer revisions to the branch heads
```

Output lands in `build/` (git-ignored):

| Path | Contents |
|---|---|
| `build/layers/` | checked-out layers (bitbake, OE-core, meta-yocto) |
| `build/downloads/`, `build/sstate-cache/` | shared between boards |
| `build/<board>/tmp/deploy/images/<machine>/` | images |

Layer revisions are pinned in `kas/boards/<board>.lock.yml`, which kas picks
up automatically.

## BeagleBone Black

### Flash an SD card

The image is `stone-ocean-gateway-image-beaglebone-yocto.rootfs.wic.zst`
with a `.wic.bmap` next to it. Find the card with `lsblk`, then:

```sh
cd build/beaglebone-black/tmp/deploy/images/beaglebone-yocto
sudo bmaptool copy stone-ocean-gateway-image-beaglebone-yocto.rootfs.wic.zst /dev/sdX
```

Without `bmaptool`: `zstdcat <image>.wic.zst | sudo dd of=/dev/sdX bs=4M conv=fsync`.

### Boot

1. Insert the card, connect Ethernet and plug the BLE dongle into the USB-A
   port.
2. Hold the **S2 (BOOT)** button while applying power, so the board boots
   from the SD card instead of the eMMC. Release it once the LEDs light up.
3. The serial console is on the 6-pin J1 header (3.3 V FTDI cable,
   115200 8N1).
4. `ssh root@stone-ocean-gw.local`, or use the DHCP address from your router.

### Check the mesh stack

```sh
lsusb                                 # the dongle shows up
hciconfig -a                          # hci0 is present
systemctl status bluetooth-mesh       # active (running)
journalctl -u bluetooth-mesh -b
```

If `bluetooth-mesh` is not running, check `dmesg | grep -i blue` for missing
firmware.

## Provisioning a node with mesh-cfgclient

This is the spec 10 hardware check, before the spec 12 gateway tool exists.
Flash and boot the node first; it beacons as unprovisioned with a UUID that
starts `73746f6e656f6365616e` ("stoneocean").

```
# mesh-cfgclient
[mesh-cfgclient]# create                       # first run only: new network, primary net key 0
[mesh-cfgclient]# appkey-create 0 0            # app key 0 on net key 0
[mesh-cfgclient]# discover-unprovisioned on    # wait for the node's UUID
[mesh-cfgclient]# provision <uuid>
[mesh-cfgclient]# menu config
[config]# target <unicast>                     # address printed after provisioning
[config]# composition-get
[config]# appkey-add 0
```

The network, keys and node list are kept in `~/.config/meshcfg/` and in
`bluetooth-meshd`'s `/var/lib/bluetooth/mesh/`, both on the SD card's root
filesystem, so they survive a reboot of the gateway.

## Security notes

- Root has no password. Do not connect the gateway to an untrusted network.
- `algif_aead` is enabled because `bluetooth-meshd` cannot run without it.
  It was the subject of CVE-2026-31431 (local privilege escalation), fixed
  upstream by "crypto: algif_aead - Revert to operating out-of-place". Keep the
  pinned OE-core revision on a linux-yocto that contains that fix.

## Layout and adding a board

```
kas/common.yml               board-independent: layers, distro, image
kas/boards/<board>.yml       machine + BSP layers for one board
kas/boards/<board>.lock.yml  pinned layer revisions for that board
layers/meta-stone-ocean/
  conf/distro/stone-ocean.conf                 systemd, trimmed DISTRO_FEATURES, hostname
  recipes-core/images/stone-ocean-gateway-image.bb
  recipes-core/packagegroups/packagegroup-stone-ocean-gateway.bb   what the gateway installs
  recipes-connectivity/bluez5/                 mesh on, bluetooth-meshd instead of bluetoothd
  recipes-connectivity/stone-ocean-netconf/    mDNS drop-ins
  recipes-kernel/linux/stone-ocean-kernel.inc  board-independent kernel fragments
  recipes-kernel/linux/linux-yocto_%.bbappend  applies them to linux-yocto
scripts/build.sh             kas-container wrapper
```

Nothing in `meta-stone-ocean` names a machine. To add a board, for example a
Raspberry Pi 4:

1. Add `kas/boards/raspberrypi4.yml`: include `kas/common.yml`, set
   `machine:`, and add the BSP layer repo (`meta-raspberrypi`, branch
   `wrynose`) under `repos:`.
2. If the board's kernel is not `linux-yocto`, add
   `recipes-kernel/linux/<kernel-recipe>_%.bbappend` containing
   `require stone-ocean-kernel.inc`. This works for any kernel recipe that
   merges `.cfg` fragments (`kernel-yocto`), such as `linux-raspberrypi`.
3. Board-only settings (a kernel fragment, a device-tree overlay) go in that
   bbappend or the board's kas file, under the machine's override, not in the
   shared files.
4. Run `scripts/build.sh raspberrypi4 lock`, then `scripts/build.sh raspberrypi4`.

When the spec 12 gateway tool runs on the gateway itself, add its runtime
(Python 3 and its D-Bus library) to `packagegroup-stone-ocean-gateway`.
