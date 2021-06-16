#!/bin/bash
#TTAK Ubuntu 18/20 LTS LUKS resize script Alpha V0.2

PROGNAME=$0

usage() {
  cat << EOF >&2
  Usage: luksShrink -p <part> -s <size> [-g <volume group name>] [-h]
    -p <part> : Partition containing the LUKS volume to resize
    -s <size> : New desired size for the LUKS volume
    -g <volume group name> : Chose volume group instead of standard ubuntu-vg
    -t Test only, simulate actions
    -h : Print this

EOF
  exit 1
}

if [ "$EUID" -ne 0 ]
  then echo "Please run this script as root (for ex : sudo $PROGNAME ...)"
  exit
fi

unset part newlukssize UBUNTU_VG TEST_ONLY
cryptopen=false
ubuntuvgopen=false
UBUNTU_VG="ubuntu-vg"
TEST_ONLY=false

while getopts 'p:s:g:t:?h' o;
do
        case $o in
                (p) part=$OPTARG;;
                (s) newlukssize=$OPTARG;;
                (g) UBUNTU_VG=$OPTARG;;
                (t) TEST_ONLY=true;;
                (h|?) usage ;;
        esac
done
shift "$((OPTIND - 1))"


#check the size existence
if [[ -z $newlukssize ]]
then
  echo "Error : Missing new partition size"
  usage
fi

#check if a part name have been given
if [[ -z $part ]]
then
  echo "Error : Missing partition name"
  usage
fi

#check the name of the target partition
if [[ $part != /dev/* ]]
then
  echo "Error : Invalid target partition name"
  usage
fi

#Handle failures
giveup()
{
	#Closing VG if necessary
  $ubuntuvgopen || vgchange -a n $UBUNTU_VG || ubuntuvgopen=false
  #Closing cryptdisk if necessary
  $cryptopen || cryptsetup close cryptdisk || cryptopen=false
	exit $1
}

getVgPartNb()
{
  echo $1 | grep -Eo '[0-9]+$'
}

#get the parent disk of the part given in argument
getDisk()
{
	diskname=`lsblk -no pkname $1`
  echo /dev/$diskname
}

#Checking if the disk and part are coherent
disk=`getDisk $part` || giveup 2
lsblk $disk || giveup 3
echo "Selected disk : $disk   Selected partition : $part"


echo "=>Oppening luks crypted volume"
cryptsetup luksOpen "$part" cryptdisk || giveup 4
cryptopen=true

echo "=>Getting gawk"
apt-get update || giveup 6
apt-get install -y gawk || giveup 6

echo "=>searching for vg"
vgscan

echo "=>selecting $UBUNTU_VG"
vgchange -ay $UBUNTU_VG || giveup 7
ubuntuvgopen=true

echo "=>checking vgroup health"
e2fsck -f /dev/$UBUNTU_VG/root || giveup 10

echo "=>resizing $UBUNTU_VG/root to $newlukssize"
$TEST_ONLY || lvresize -L $newlukssize --resizefs $UBUNTU_VG/root || giveup 8

#We need a better way to defrag the LVM PV
SWAP_PV_POS=`pvs -v --segments /dev/mapper/cryptdisk | grep swap_1 | awk '{print $12}'`
echo "=>moving swap $SWAP_PV_POS"
$TEST_ONLY || pvmove --alloc anywhere "$SWAP_PV_POS" || giveup 9

echo "=>checking vgroup health"
e2fsck -f /dev/$UBUNTU_VG/root || giveup 10

#We need a symplier and more reliable way to get these values
echo "=>resizing LVM physical volume"
PE_COUNT=`pvdisplay /dev/mapper/cryptdisk | grep "Allocated PE" | awk '{print $3}'`
PE_SIZE=`pvdisplay /dev/mapper/cryptdisk | grep "PE Size" | awk '{print $3}' | cut -d. -f1 | cut -d, -f1`
UNUSABLE_SIZE=`pvdisplay /dev/mapper/cryptdisk | grep "PV Size" | awk '{print $8}' | cut -d. -f1 | cut -d, -f1`
NEW_SIZE=`gawk -M "BEGIN {print ((($PE_COUNT+2)*$PE_SIZE)+0$UNUSABLE_SIZE)*1048576}"`
$TEST_ONLY || pvresize --setphysicalvolumesize "$NEW_SIZE"B /dev/mapper/cryptdisk || giveup 11
echo "  New size : $NEW_SIZE B"

#We need a symplier and more reliable way to get these values
echo "=>resizing LUKS volume : "
PE_COUNT=`pvdisplay /dev/mapper/cryptdisk | grep Total | awk '{print $3}'`
PE_SIZE=`pvdisplay /dev/mapper/cryptdisk | grep "PE Size" | awk '{print $3}' | cut -d. -f1 | cut -d, -f1`
LUKS_SECTOR_SIZE=`cryptsetup status cryptdisk | grep "sector size" | awk '{print $3}'`
NEW_LUKS_SECTOR_COUNT=`gawk -M "BEGIN {print ($PE_COUNT+1)*$PE_SIZE*1048576/$LUKS_SECTOR_SIZE}"`
$TEST_ONLY || cryptsetup -b $NEW_LUKS_SECTOR_COUNT resize cryptdisk || giveup 12
echo "=>New LUKS sector count : $NEW_LUKS_SECTOR_COUNT sectors"

#We need a symplier and more reliable way to get these values
PARTITION_SECTOR_START=`parted $disk 'unit s print' | grep " 3 " | awk '{print $2}' | cut -ds -f1`
LUKS_OFFSET_SECTORS=`cryptsetup status cryptdisk | grep "offset:" | awk '{print $2}'`
NEW_PARTITION_SECTOR_END=`gawk -M "BEGIN {print $PARTITION_SECTOR_START+($NEW_LUKS_SECTOR_COUNT+$LUKS_OFFSET_SECTORS)-1}"`

echo "=>Close LVM vgroup..."
vgchange -a n $UBUNTU_VG || ubuntuvgopen=false || giveup 13

echo "=>Closing LUKS volume..."
cryptsetup close cryptdisk || cryptopen=false || giveup 14


echo "=>Resizing partition to $NEW_PARTITION_SECTOR_END (please Enter the value $NEW_PARTITION_SECTOR_END)"
$TEST_ONLY || parted $disk 'unit s resizepart 3' || giveup 15

echo "=>That's all folks"
exit 0
