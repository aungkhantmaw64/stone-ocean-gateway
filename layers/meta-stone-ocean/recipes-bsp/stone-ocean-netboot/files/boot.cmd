# Dev netboot: kernel and device tree over TFTP, root filesystem over NFS.
# U-Boot's distro boot runs this from the SD card's boot partition. The
# server is read from netboot.txt next to it; edit that file on the card if
# the host's address changes.
setenv autoload no
load ${devtype} ${devnum}:${distro_bootpart} ${loadaddr} netboot.txt
env import -t ${loadaddr} ${filesize}

# The DHCP reply may set serverip, so the netboot server is applied after it.
dhcp
setenv serverip ${netboot_server}

tftp ${kernel_addr_r} @KERNEL_IMAGETYPE@
tftp ${fdt_addr_r} ${fdtfile}
setenv bootargs console=@CONSOLE@ root=/dev/nfs rw ip=dhcp nfsroot=${serverip}:@NFS_EXPORT@,v3,tcp,port=@NFS_PORT@,mountport=@MOUNT_PORT@,nolock
@BOOTCMD@ ${kernel_addr_r} - ${fdt_addr_r}
