#! /bin/sh -
#TTAK Ubuntu 18/20 LTS LUKS resize script Alpha V0.2

PROGNAME=$0

usage() {
  cat << EOF >&2
Usage: $PROGNAME -p <part> -s <size>

-p <part>: Partition containing the LUKS volume to resize
-s <size>: New desired size for the LUKS volume

EOF
  exit 1
}

while getopts p:s o; do
	case $o in
		(p) part=$OPTARG;;
		(s) newlukssize=$OPTARG;;
		(*) usage
	esac
done
shift "$((OPTIND - 1))"

UBUNTU_VG="vgubuntu"

#Handle failures
giveup()
{
	#Closing VG if necessary
	if [ -z ${ubuntuvgopen+x} ]; then vgchange -a n $UBUNTU_VG
	#Closing cryptdisk if necessary
	if [ -z ${cryptopen+x} ]; then cryptsetup close cryptdisk
	exit $1
}

#get the parent disk of the part given in argument
getDisk()
{
	echo `lsblk -no pkname $1`
}

#Checking if the disk and part are coherent
disk=`getDisk $part` || giveup 2
lsblk $disk || giveup 3
echo "Selected disk : $disk   Selected partition : $part"


echo "=>Oppening luks crypted volume"
cryptsetup luksOpen "$part" cryptdisk && cryptopen=1 || giveup 4

echo "=>Getting gawk and python3"
apt-get update && apt-get install -y gawk || giveup 6

echo "=>searching for vg"
vgscan

echo "=>selecting $UBUNTU_VG"
sudo vgchange -ay $UBUNTU_VG && ubuntuvgopen=1 || giveup 7

echo "=>resizing $UBUNTU_VG/root to $newlukssize"
lvresize -L $newlukssize --resizefs $UBUNTU_VG/root || giveup 8

#We need a better way to defrag the LVM PV
SWAP_PV_POS=`pvs -v --segments /dev/mapper/cryptdisk | grep swap_1 | awk '{print $12}'`
echo "=>moving swap $SWAP_PV_POS"
sudo pvmove --alloc anywhere "$SWAP_PV_POS" || giveup 9

echo "=>checking vgroup health"
e2fsck -f /dev/$UBUNTU_VG/root || giveup 10

#We need a symplier and more reliable way to get these values
echo "=>resizing LVM physical volume"
PE_COUNT=`pvdisplay /dev/mapper/cryptdisk | grep "Allocated PE" | awk '{print $3}'`
PE_SIZE=`pvdisplay /dev/mapper/cryptdisk | grep "PE Size" | awk '{print $3}' | cut -d. -f1`
UNUSABLE_SIZE=`pvdisplay /dev/mapper/cryptdisk | grep "PV Size" | awk '{print $8}' | cut -d. -f1`
NEW_SIZE=`gawk -M "BEGIN {print ((($PE_COUNT+2)*$PE_SIZE)+0$UNUSABLE_SIZE)*1048576}"`
pvresize --setphysicalvolumesize "$NEW_SIZE"B /dev/mapper/cryptdisk || giveup 11
echo "New size : $NEW_SIZE B"

#We need a symplier and more reliable way to get these values
echo "=>resizing LUKS volume : "
PE_COUNT=`pvdisplay /dev/mapper/cryptdisk | grep Total | awk '{print $3}'`
PE_SIZE=`pvdisplay /dev/mapper/cryptdisk | grep "PE Size" | awk '{print $3}' | cut -d. -f1`
LUKS_SECTOR_SIZE=`cryptsetup status cryptdisk | grep "sector size" | awk '{print $3}'`
NEW_LUKS_SECTOR_COUNT=`gawk -M "BEGIN {print ($PE_COUNT+1)*$PE_SIZE*1048576/$LUKS_SECTOR_SIZE}"`
cryptsetup -b $NEW_LUKS_SECTOR_COUNT resize cryptdisk || giveup 12
echo "=>New LUKS sector count : $NEW_LUKS_SECTOR_COUNT sectors"

#We need a symplier and more reliable way to get these values
PARTITION_SECTOR_START=`parted $disk 'unit s print' | grep " 3 " | awk '{print $2}' | cut -ds -f1`
LUKS_OFFSET_SECTORS=`cryptsetup status cryptdisk | grep "offset:" | awk '{print $2}'`
NEW_PARTITION_SECTOR_END=`gawk -M "BEGIN {print $PARTITION_SECTOR_START+($NEW_LUKS_SECTOR_COUNT+$LUKS_OFFSET_SECTORS)-1}"`

echo "=>Close LVM vgroup..."
vgchange -a n $UBUNTU_VG && unset ubuntuvgopen || giveup 13

echo "=>Closing LUKS volume..."
cryptsetup close cryptdisk && unset cryptopen || giveup 14

echo "=>Resizing partition to $NEW_PARTITION_SECTOR_END (please Enter the value $NEW_PARTITION_SECTOR_END)"
parted $disk 'unit s resizepart 3' || giveup 15

echo "=>That's all folks"
exit 0
