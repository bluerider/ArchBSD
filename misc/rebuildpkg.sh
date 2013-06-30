#!/usr/bin/bash

# Rebuild all packages from rebuild.txt

if (( $# < 1 )); then
	echo "Usage: $(basename $0) <path to rebuild.txt>"
	echo "  example: $(basename $0) ./rebuilds.txt"
	exit 1
fi

# Source makepkg.conf; fail if it is not found
if [[ -r '/etc/makepkg.conf' ]]; then
	source '/etc/makepkg.conf'
else
	die '/etc/makepkg.conf not found!'
fi

bump_pkgrel() {
	# Get the current pkgrel from SVN and update the working copy with it
	# This prevents us from incrementing out of control :)
	pbuild='PKGBUILD'
	oldrel=$(grep 'pkgrel=' $pbuild | cut -d= -f2)

	#remove decimals
	rel=$(echo $oldrel | cut -d. -f1)

	newrel=$(($rel + 1))

	gsed -i "s/pkgrel=$oldrel/pkgrel=$newrel/" PKGBUILD
}

pkg_from_pkgbuild() {
	# we want the sourcing to be done in a subshell so we don't pollute our current namespace
	export CARCH PKGEXT
	(source PKGBUILD; echo "$pkgname-$pkgver-$pkgrel-$CARCH$PKGEXT")
}

pkgs="$1"

GITPATH='git://githut.com/Amzo/ArchBSD'

REBUILD_ROOT="$(pwd)"
mkdir -p "$REBUILD_ROOT"
cd "$REBUILD_ROOT"

/usr/bin/git clone git://github.com/Amzo/ArchBSD -b abs

FAILED=""
while read pkg
do
	cd "$REBUILD_ROOT/ArchBSD/extra/$pkg"

	bump_pkgrel

		pkgfile=PKGBUILD
		if [[ -e $pkgfile ]]; then
		makepkg --sign		
		else
			FAILED="$FAILED $pkg"
			error "$pkg Failed, no package built!"
		fi
done < "$pkgs"

cd "$REBUILD_ROOT"

msg 'git pkgbumps - commit when ready'
