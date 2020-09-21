# luksShrink
Ubuntu LTS 18 luks volume resize script

<p>Disclaimer, **this script is not (yet) intended for production purpose**. Do not use it on anything with important data and **do a backup beforehand.**</p>

## Version - Alpha 0.2 Work in progress

For now, **it should be only used it on a fresh luks full disk Ubuntu 18/20 install**

<p>It has been tested with Ubuntu 18 in EFI boot mode only but it should also work the same way on with the -g option to select the right Volume Group on Ubuntu 20</p>

This script allow to shrink an LVM on LUKS Ubuntu Volume

Usage: luksShrink -p part -s size

## Usecases:

### Create a working encrypted dualboot windows 10(Bitlocker) + Ubuntu 18/20(LUKS)

>####Ubuntu LTS 18/20 dualboot install :
1. Install Ubuntu on the whole disk with LVM+LUKS enable
2. Boot on it to check everything is working
3. Reboot on the live usb of ubuntu LTS 18/20
4. Execute this script to shrink the LVM on LUKS volume of ubuntu to get space for Windows 10
5. install Windows 10 on the free space
6. reboot on Windows and check everything is fine, DO NOT ENABLE BITLOCKER AT THIS POINT
7. reboot to modify back EFI boot in BIOS to ubuntu(Grub)
8. Boot on Ubuntu and do a >sudo update-grub
9. Reboot on windows using Grub and enable bitlocker.
You should now have a fully fonctionnal encrypted dualboot windows 10(Bitlocker) + Ubuntu 18/20(LUKS)

## Examples :

>luksShrink -p /dev/nvme0n1p3 -s 200G

is going to shrink /dev/nvme0n1p3 to 200G using ubuntu-vg as default volume group

>luksShrink -p /dev/nvme0n1p3 -s 300G -g vgcustom

is going to shrink /dev/nvme0n1p3 to 300G using vgcustom as default volume group
