#!/usr/bin/bash

msg() {
	local mesg=$1; shift
	printf "\033[1;34m==>\033[0;0m ${mesg}\n" "$@"
}

want_unmount=0
die() {
	msg "$@"
	if (( $want_unmount )); then
		do_unmount
	fi
	exit 1
}

cachedir=/var/cache/pacman/pkg

abstree=$HOME/Sources/ArchBSD
buildtop=$HOME/ABSD-Build

configfile="/etc/archbsd-build.conf"

if [ ! -f "$configfile" ]; then
	die "please create a config in $configfile"
fi

source "$configfile"

package_output=${package_output:-${buildtop}/output}
builder_bashrc=${builder_bashrc:-${buildtop}/bashrc}
setup_script=${setup_script:-${buildtop}/setup_root}
prepare_script=${prepare_script:-${buildtop}/prepare_root}

do_unmount() {
	umount "${builddir}"/{dev,proc,var/cache/pacman/pkg}
}
want_unmount=0

progname=${0##*/}
usage() {
	cat <<EOF
usage: $progname [options] <repo> <package>
options:
  -h      show this help
  -k      remove the build dir and quit
  -n      don't clean the build dir (useful for continuing)
  -x      use the existing build dir instead of reinstalling
  -y      don't sync the repositories via pacman -Sy
  -u      update an existing chroot
  -C      do not use the --noconfirm option on commands
  -s      open a shell in the chroot as builder
  -S      open a shell in the chroot as root
  -R      add -R to makepkg
  -e      pass -e to makepkg (keeping previous pkg/ and src/ dirs intact)
  -L      remove ld-elf.so.hints before trying to chroot
  -i PKG  install this package before building (NOT recommended)
EOF
}

opt_noclean=0
opt_nosync=0
opt_existing_install=0
opt_confirm=--noconfirm
opt_kill=0
opt_update_install=0
opt_shell=0
opt_install=()
opt_repackage=0
opt_keepbuild=0
opt_kill_ld=0
OPTIND=1
while getopts ":hknxyuCsSReLi:" opt; do
	case $opt in
		h) usage; exit 0;;
		k) opt_kill=1 ;;
		n) opt_noclean=1 ;;
		s) opt_shell=1 ;;
		S) opt_shell=2 ;;
		x) opt_existing_install=1 ; opt_noclean=1 ;;
		y) opt_nosync=1 ;;
		u) opt_update_install=1; opt_existing_install=1 ; opt_noclean=1 ;;
		C) opt_confirm="" ;;
		i) opt_update_install=1; opt_install=("${opt_install[@]}" $OPTARG) ;;
		R) opt_noclean=1 ; opt_existing_install=1 ; opt_repackage=1 ; opt_keepbuild=1 ;;
		e) opt_keepbuild=1 ;;
		L) opt_kill_ld=1 ;;
		\:) usage ; exit 1 ;;
		\?) usage ; exit 1 ;;
		*) : ;;
	esac
done
shift $((OPTIND-1))

makepkgargs=()

if [[ $opt_repackage == 1 ]]; then
	makepkgargs=("${makepkgargs[@]}" -R)
fi
if [[ $opt_keepbuild == 1 ]]; then
	makepkgargs=("${makepkgargs[@]}" -e)
fi

msg "Additional packages: ${opt_install[@]}"

if (( $# != 2 )); then
	usage
	exit 1
fi

if (( $opt_kill )); then opt_noclean=0; fi

get_full_version() {
	if [[ -z $1 ]]; then
		if [[ $epoch ]] && (( ! $epoch )); then
			printf "%s\n" "$pkgver-$pkgrel"
		else
			printf "%s\n" "$epoch:$pkgver-$pkgrel"
		fi
	else
		for i in pkgver pkgrel epoch; do
			local indirect="${i}_override"
			eval $(declare -f package_$1 | gsed -n "s/\(^[[:space:]]*$i=\)/${i}_override=/p")
			[[ -z ${!indirect} ]] && eval ${indirect}=\"${!i}\"
		done
		if (( ! $epoch_override )); then
			printf "%s\n" "$pkgver_override-$pkgrel_override"
		else
			printf "%s\n" "$epoch_override:$pkgver_override-$pkgrel_override"
		fi
	fi
}

getsource() {
	cd "${fullpath}"
	source PKGBUILD
	pkgbase=${pkgbase:-${pkgname[0]}}
	epoch=${epoch:-0}
	fullver=$(get_full_version)
	echo "${pkgbase}-${fullver}${SRCEXT}"
}

#
# Handle options
#
source /etc/makepkg.conf
if (( ! ${#PACKAGER} )); then
	die "Empty PACKAGER variable not allowed in /etc/makepkg.conf"
fi
# don't allow the commented out thing either: :P
if [[ $PACKAGER == "John Doe <john@doe.com>" ]]; then
	die "Please update the PACKAGER variable in /etc/makepkg.conf"
fi


repo="$1"
package="$2"
# updated msg:
msg() {
	local mesg=$1; shift
	printf "\033[1;34m==>\033[0;0m [$repo/$package] ${mesg}\n" "$@"
}

fullpath="$abstree/$repo/$package"
fulloutput="$package_output/$repo"

#
# Check options
#
[ -d "$fullpath" ] || die "No such package found in abs-tree"
[ -e "$fullpath/PKGBUILD" ] || die "No PKGBUILD found for package %s" "$package"

#
# Create source package
#
#msg "Creating source package..."
cd "$fullpath"
#makepkg -Sf || die "failed creating src package"

srcpkg=$(getsource)
[ -f "$srcpkg" ] || die "Not a valid source package: %s" "$srcpkg"

#
# Build paths:
#
builddir="$buildtop/$repo/$package"

#
# Kill previous stuff
#

#
# Clean previous stuff
#
if (( ! $opt_noclean )); then
	msg "Cleaning previous work..."
	umount "${builddir}/dev" 2>/dev/null
	umount "${builddir}/proc" 2>/dev/null
	umount "${builddir}/var/cache/pacman/pkg" 2>/dev/null
	find "$builddir" -print0 | xargs -0 chflags noschg
	rm -rf "$builddir"
	if (( $opt_kill )); then exit 0; fi
fi

#
# Create chroot
#
msg "Installing chroot environment..."
mkdir -p "$builddir" || die "Failed to create build dir: %s" "$builddir"
mkdir -p "$builddir/var/lib/pacman"

pacman_rootopt=(--config /etc/pacman.conf.clean --root "$builddir" --cachedir "$cachedir")

if (( ! $opt_nosync )); then
	if ! pacman $opt_confirm "${pacman_rootopt[@]}" -Sy; then
		die "Failed to sync databases"
	fi
fi

if (( ! $opt_existing_install )); then
	if ! pacman $opt_confirm "${pacman_rootopt[@]}" -Su freebsd-world bash freebsd-init base base-devel "${opt_install[@]}"; then
		die "Failed to install build chroot"
	fi
elif (( $opt_update_install )); then
	if ! pacman $opt_confirm "${pacman_rootopt[@]}" -Su --needed "${opt_install[@]}"; then
		die "Failed to update build chroot"
	fi
fi

install -m644 /etc/pacman.conf.clean "${builddir}/etc/pacman.conf"

#
# Configure the chroot
#
echo 'PACKAGER="'"$PACKAGER"\" >> "$builddir/etc/makepkg.conf" \
	|| die "Failed to add PACKAGER information"

install -dm755 "${builddir}/var/cache/pacman/pkg" || die "Failed to setup package cache mountpoint"
want_unmount=1
mount_nullfs {,"${builddir}"}/var/cache/pacman/pkg || die "Failed to bind package cache"
mount -t devfs devfs "${builddir}/dev" || die "Failed to mount devfs"
mount -t procfs procfs "${builddir}/proc" || die "Failed to mount procfs"

if (( $opt_kill_ld )); then
	msg "Killing previous ld-hints"
	rm -f "${builddir}/var/run/ld{,-elf,elf32,32}.so.hints"
fi

msg "Running setup script %s" "$setup_script"
install -m644 "$setup_script" "${builddir}/root/setup.sh"
chroot "${builddir}" /usr/bin/bash /root/setup.sh

#
# Create the user:
#
msg "Initializing the keyring"
chroot "${builddir}" pacman-key --init
chroot "${builddir}" pacman-key --populate archbsd

msg "Setting up networking"
install -m644 /etc/resolv.conf "${builddir}/etc/resolv.conf"

msg "Creating user 'builder'"
chroot "${builddir}" pw userdel builder || true
chroot "${builddir}" pw useradd -n builder -u 1001 -c builder -s /usr/bin/bash -m \
	|| die "Failed to create user 'builder'"

msg "Installing shell profile..."
install -o 1001 -m644 "$builder_bashrc" "${builddir}/home/builder/.bashrc"

msg "Installing package building directory"
install -o 1001 -dm755 "${builddir}/home/builder/package"
install -o 1001 -m644 "$fullpath/$srcpkg" "${builddir}/home/builder/package"

msg "Unpacking package sources"
chroot "${builddir}" /usr/bin/su -l builder -c "cd ~/package && bsdtar --strip-components=1 -xvf ${srcpkg}" || die "Failed to unpack sources"
source "$fullpath/PKGBUILD"
for i in "${source[@]}"; do
	case "$i" in
		*::*) i=${i%::*} ;;
		*)    i=${i##*/} ;;
	esac
	if [ -e "$fullpath/$i" ]; then
		msg "Copying file %s" "$i"
		install -o 1001 -m644 "$fullpath/$i" "${builddir}/home/builder/package/$i"
	else
		msg "You don't have this file? %s" "$i"
	fi
done

msg "Syncing dependencies"
synccmd=(--asroot --nobuild --syncdeps --noconfirm --noextract)
chroot "${builddir}" /usr/bin/bash -c "cd /home/builder/package && makepkg ${synccmd[*]}" || die "Failed to sync package dependencies"
[[ $opt_keepbuild == 1 ]] || chroot "${builddir}" /usr/bin/bash -c "cd /home/builder/package && rm -rf pkg src"        || die "Failed to clean package build directory"
chroot "${builddir}" /usr/bin/bash -c "chown -R builder:builder /home/builder/package"    || die "Failed to reown package directory"

msg "Running prepare script %s" "$prepare_script"
install -m644 "$prepare_script" "${builddir}/root/prepare.sh"
chroot "${builddir}" /usr/bin/bash /root/prepare.sh

if (( $opt_shell == 1 )); then
	msg "Entering chroot as builder"
	chroot "${builddir}" /usr/bin/su -l builder
elif (( $opt_shell == 2 )); then
	msg "Entering chroot as root"
	chroot "${builddir}" /usr/bin/bash
else
	msg "Starting build"
	chroot "${builddir}" /usr/bin/su -l builder -c "cd ~/package && makepkg ${makepkgargs[*]}" || die "Failed to build package"
	
	msg "Copying package archives"
	mkdir -p "$fulloutput"
	mv "${builddir}/home/builder/package/"*.pkg.tar.xz "$fulloutput" ||
		die "Failed to fetch packages..."
fi
msg "Unmounting stuff"
do_unmount
