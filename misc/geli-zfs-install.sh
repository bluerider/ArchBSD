#!/usr/bin/bash

#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
# Copyright (C) 2013 Kim Carlbäcker <kim.carlbacker@gmail.com>
#
# Everyone is permitted to copy and distribute verbatim or modified
# copies of this license document, and changing it is allowed as long
# as the name is changed.
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

msg() {
	local mesg=$1; shift
	printf "\033[1;43m==>\033[0;0m ${mesg}\n" "$@"
}

TANK_NAME="tank"
ROOT=('ada0' 'ada1')
boot="ada2"

if [ "$1" == "clean" ]; then
	$(mount | grep "/boot/zfs")
	if [ $? -eq 0 ]; then
		$(umount /boot/zfs)
		$(mdconfig -d -u 2)
	$(mount | grep "/mnt/boot")
	if [ $? -eq 0 ]; then
		$(umount /mnt/boot)
		$(rmdir /tmp/boot)
	fi
	$(mount | grep "/tmp/boot")
	if [ $? -eq 0 ]; then
		$(umount /tmp/boot)
		$(rmdir /tmp/boot)
	fi
	if [ -d /var/backups ]; then
		$(rm -r /var/backups)
	fi
	$(gpart destroy -F ${boot})
	for disk in ${ROOT[@]}; do
		$(gpart destroy -F ${disk})
	done
	exit 1
fi

msg " Creating /var/backups"
mkdir /var/backups

msg " Setting up boot-disk..."
gpart create -s gpt $boot
gpart add -s 128k -t freebsd-boot $boot # should become ${boot}p1
gpart add -t freebsd-ufs $boot # should become ${boot}p2

msg " Setting up boot-loader..."
gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i1 $boot

msg " Mounting /boot in /tmp..."
mkdir /tmp/boot
mount /dev/${boot}p2 /tmp/boot

msg " Creating encryption-keys..."
dd if=/dev/random of=/tmp/boot/root.key bs=128k count=1

msg " Setting up root-disks..."
for disk in ${ROOT[@]}; do
	gpart create -s gpt $disk
	gpart add -t freebsd-zfs $disk # should becode ${disk}p1
	geli init -b -K /tmp/boot/root.key -s 4096 -l 256 /dev/${disk}p1
	geli attach -k /tmp/boot/root.key /dev/${disk}p1
done

GELI_ROOT=()
for geli in ${ROOT[@]}; do
	GELI_ROOT+=("${geli}p1.eli")
done

msg " Setting up the ZFS Pool..."
case ${#GELI_ROOT[@]} in
	1)
		zpool create $TANK_NAME ${GELI_ROOT[@]}
		;;
	2)
		zpool create $TANK_NAME mirror ${GELI_ROOT[@]}
		;;
	*)
		zpool create $TANK_NAME raidz ${GELI_ROOT[@]}
		;;
esac

msg " Creating and Mounting /boot/zfs for zpool.cache..."
mdconfig -a -t malloc -s 64m -u 2
newfs -O2 /dev/md2
mount /dev/md2 /boot/zfs

msg " Re-importing zpool..."
zpool export ${TANK_NAME}
zpool import -o altroot=/mnt -o cachefile=/boot/zfs/zpool.cache -f ${TANK_NAME}

msg " Setting up zfs checksum..."
zfs set checksum=fletcher4 ${TANK_NAME}

msg " Setting up basic datasets..."
zfs create -o canmount=off -o mountpoint=legacy ${TANK_NAME}/ROOT
zfs create -o canmount=on -o compression=on -o mountpoint=/ ${TANK_NAME}/ROOT/archbsd-0
zfs create -o compression=on -o mountpoint=/home ${TANK_NAME}/HOME
zfs create -o compression=off -o mountpoint=/root ${TANK_NAME}/ROOT/root

msg " Remounting boot..."
umount /tmp/boot
rmdir /tmp/boot
mount /dev/${boot} /mnt/boot

msg " Copying zpool.cache..."
mkdir /mnt/boot/zfs
cp /boot/zfs/zpool.cache /mnt/boot/zfs/zpool.cache

