# luksShrink
Ubuntu LTS 18 luks volume shrink script

<p>Disclaimer, <b>this script is not (yet) intended for production purpose.</b> Do not use it on anything with important data and <b>do a backup beforehand</b>.</p>

## Version - Alpha 0.2 Work in progress
This script allow to shrink an LVM on LUKS Ubuntu Volume offline

**Usage:**
```
Usage: luksShrink -p <part> -s <size> [-g <volume group name>] [-h]
  -p <part> : Partition containing the LUKS volume to resize
  -s <size> : New desired size for the LUKS volume
  -g <volume group name> : Chose volume group instead of standard ubuntu-vg
  -h : Print this
```
For now, **it should be only used it on a fresh luks full disk Ubuntu 18/20 install offline**

<p>It has been tested with Ubuntu 18 in EFI boot mode only but it should also work the same way on with the -g option to select the right Volume Group on Ubuntu 20</p>

## Usecases:

### Create a working encrypted dualboot windows 10(Bitlocker) + Ubuntu 18/20(LUKS)

>#### Ubuntu LTS 18/20 dualboot install :
>1. Install Ubuntu on the whole disk with LVM+LUKS enable
>2. Boot on it to check everything is working
>3. Reboot on the live usb of ubuntu LTS 18/20
>4. Execute this script to shrink the LVM on LUKS volume of ubuntu to get space for Windows 10
>5. install Windows 10 on the free space
>6. reboot on Windows and check everything is fine, DO NOT ENABLE BITLOCKER AT THIS POINT
>7. reboot to modify back EFI boot in BIOS to ubuntu(Grub)
>8. Boot on Ubuntu and do a >sudo update-grub
>9. Reboot on windows using Grub and enable bitlocker.
>10. You should now have a fully fonctionnal encrypted dualboot windows 10(Bitlocker) + Ubuntu 18/20(LUKS)

## Examples :

```bash
luksShrink -p /dev/nvme0n1p3 -s 200G
```
is going to shrink /dev/nvme0n1p3 to 200G using ubuntu-vg as default volume group

```bash
luksShrink -p /dev/nvme0n1p3 -s 300G -g vgcustom
```
is going to shrink /dev/nvme0n1p3 to 300G using vgcustom as volume group
