#!/usr/bin/bash

#######################################
# Commons for Minimal ArchBSD ISO/IMG #
#######################################

#Set some variables
curdir=`pwd`
temproot=${curdir}/ArchBSD_temp
isoroot=${curdir}/ArchBSD_iso
files=${curdir}/files
#Since we're not checkign deps, and need libiconv and bash installed in the correct order
packagelist="archbsd-keyring ca_root_nss curl cyrus-sasl gnupg gpgme libarchive libassuan libgcrypt libgpg-error libksba libldap libsasl libtool pacman-mirrorlist pinentry pkgconf pth freebsd-kernel gcc-libs libpthread-stubs openrc pacman nano"
date=`date +"%d%m%Y"`


check() {
        if [ $UID -ne 0 ]; then
                echo "This script needs to be run as root" && exit
        fi

	if [ ! -e ${files}/filelist ]; then
		echo "Filelist doesn't exist" && exit
	fi

        if [ ! -e ${files}/dirlist ]; then
                echo "Dirlist doesn't exist" && exit
        fi

	if [ ! -d ${temproot} ]; then
		mkdir ${temproot}
	fi

        if [ ! -d ${isoroot} ]; then
                mkdir ${isoroot}
        fi

        if [ ! -d ${imgroot} ]; then
        	mkdir ${imgroot}
	fi
}

mktemproot() {
	install -dm755 ${temproot}/etc
	install -m644 ${files}/pacman.conf.clean ${temproot}/etc/pacman.conf
	install -dm755 ${temproot}/var/{lib,cache}/pacman
	pacman -Sy base --config ${temproot}/etc/pacman.conf -r ${temproot} --cachedir ${temproot}/var/cache/pacman/pkg/
}

mkdirlayout() {
	for dir in bin  boot  dev  etc  lib  libexec  \
		 media  mnt  proc  rescue  root  \
		 sbin  sys  tmp  usr  var rw_etc rw_var; do
	install -dm755 ${isoroot}/${dir}
	done
	install -m644 ${files}/pacman.conf.clean ${isoroot}/etc/pacman.conf

	for dirs in usr/bin usr/sbin usr/libexec usr/share usr/lib; do
		install -dm755 ${isoroot}/${dirs}
	done

        install -dm755 ${isoroot}/var/{lib,cache}/pacman

}

copyfiles() {
	while read file; do
		cp -a ${temproot}${file} ${isoroot}${file}
	done < ${files}/filelist

        while read libfile; do
                cp -Ra ${temproot}${libfile} ${isoroot}/usr/lib/
	done < ${files}/liblist
}

copydirs() {
	while read dir; do
		cp -a ${temproot}${dir} ${isoroot}${dir}
	done < ${files}/dirlist

	for cdirs in bin sbin libexec lib; do
		cp -a ${temproot}/${cdirs} ${isoroot}/
	done
}

package_install() {
	pacman -Sydd --config ${temproot}/etc/pacman.conf --force libiconv -r ${isoroot} --cachedir ${temproot}/var/cache/pacman/pkg/ --noconfirm
	pacman -Sy --force bash --config ${temproot}/etc/pacman.conf -r ${isoroot} --cachedir ${temproot}/var/cache/pacman/pkg/ --noconfirm
	pacman -Sydd --force ${packagelist} --config ${temproot}/etc/pacman.conf -r ${isoroot} --cachedir ${temproot}/var/cache/pacman/pkg/ --noconfirm
}

config_setup() {
	#mount dev to add keys
	mount -t devfs devfs ${isoroot}/dev
	cp ${files}/fstab ${isoroot}/etc/fstab
	cp ${files}/cshrc ${isoroot}/root/.cshrc		
	rm -f ${isoroot}/etc/runlevels/boot/root
	chroot ${isoroot} /sbin/rc-update add modules default
	chroot ${isoroot} /sbin/rc-update add devd default
        chroot ${isoroot} /sbin/ldconfig -m /usr/lib
        chroot ${isoroot} /sbin/ldconfig -m /usr/local/lib
        chroot ${isoroot} /sbin/ldconfig -m /lib
	cp ${files}/modules ${isoroot}/etc/conf.d/modules
	echo 'HOSTNAME="ArchBSD"' > ${isoroot}/etc/conf.d/hostname
	install -m755 ${files}/install.txt ${isoroot}/root/install.txt
 	install -m644 ${files}/pacstrap ${isoroot}/usr/bin/pacstrap
	chmod +x ${isoroot}/usr/bin/pacstrap	
	cp -a /etc/pacman.d/gnupg "$isoroot/etc/pacman.d/"
	chroot ${isoroot} /usr/bin/pacman-key --init
        chroot ${isoroot} /usr/bin/pacman-key --populate archbsd
 	#unmount devfs
	umount ${isoroot}/dev
}
