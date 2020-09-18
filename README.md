# luksShrink
Ubuntu LTS 18->20 luks volume resize script
Tested on EFI boot mode only


##Version - Alpha 0.2
This script allow to shrink an LVM on LUKS Ubuntu Volume

Usage: luksShrink -p part -s size

Example : luksShrink -p /dev/nvme0n1p3 -s 200G
This is going to shrink /dev/nvme0n1p3 to 200G

This is typically usefull to create a working encrypted dualboot windows 10(Bitlocker) + Ubuntu 18/20(LUKS)

To do so, you can proceed as follow :
1) Install Ubuntu on the whole disk with LVM+LUKS enable
2) Boot on it to check everything is working
3) Reboot on the live usb of ubuntu LTS 18/20
4) Execute this script to shrink the LVM on LUKS volume of ubuntu to get space for Windows 10
5) install Windows 10 on the free space
6) reboot on Windows and check everything is fine, DO NOT ENABLE BITLOCKER AT THIS POINT
7) reboot to modify back EFI boot in BIOS to ubuntu(Grub)
8) Boot on Ubuntu and do a >sudo update-grub
9) Reboot on windows using Grub and enable bitlocker.

You should now have a fully fonctionnal encrypted dualboot windows 10(Bitlocker) + Ubuntu 18/20(LUKS)
