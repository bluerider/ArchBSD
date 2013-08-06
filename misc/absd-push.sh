#!/usr/bin/bash

die() {
	echo "*** $@"
	exit 1
}

arg0=$0
repo=$1
shift

case "$repo" in
	core|extra|community|testing)
		echo "Pushing to repository: $repo"
		;;
	*)
		die "usage: $arg0 repository files..."
		;;
esac

uplist=()
for i in "$@"; do
	[ -f "${i}.sig" ] || gpg --detach-sign "$i" || die "signing failed"
	gpg --verify "./${i}.sig" || \
		gpg --detach-sign "$i" || die "can't sign package"
	uplist=("${uplist[@]}" "./$i" "./${i}.sig")
done

scp "${uplist[@]}" "archbsd.net:Packages/$repo/"
