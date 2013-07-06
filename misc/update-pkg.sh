#!/bin/sh

TARGET=/home/amzo/public_ftp
CARCH=x86_64

prog=$0
usage() {
	echo "$prog <repo> files..."
	exit 1
}

die() {
	echo "$@"
	exit 1
}

force=no
if [ "x$1" = "x-f" ]; then
	shift
	force=yes
fi

keep=no
if [ "x$1" = "x-k" ]; then
	shift
	keep=yes
fi

repo=$1
shift

case "$repo" in
	core|extra|community|testing) : ;;
	*) usage ;;
esac

target="${TARGET}/${repo}/os/$CARCH"
updatepkg() {
	pkgfile=$1
	pkgname=`echo "$pkgfile" | pcregrep -o '^.*?(?=-[0-9])'`

	if [ "x$force" = "xno" ]; then
		test -e "${target}/${repo}.db.tar.gz" || die "no ${repo}.db.tar.gz found in target directory"
	fi

	test -e "$pkgfile" || die "$prog: $pkgfile: no such file"

	case "$pkgfile" in
		*-${CARCH}.pkg.tar.xz) : ;;
		*-any.pkg.tar.xz) : ;;
		*) die "invalid architecture" ;;
	esac

	test -e "${pkgfile}.sig" || die "$prog: $pkgfile: missing signature"

	cp -v "${pkgfile}" "${target}/${pkgfile}"         || die "failed to copy $pkgfile"
	cp -v "${pkgfile}.sig" "${target}/${pkgfile}.sig" || die "failed to copy ${pkgfile}.sig"

	olddir=$PWD
	cd "$target" || die "failed to change directory to $target"
	repo-add -f "${repo}.db.tar.gz" "${pkgfile}"
	for i in "${pkgname}"-*.pkg.tar.xz; do
		case "$i" in
			$pkgfile) : ;;
			${pkgname}-[0-9]*.pkg.tar.xz)
				rm -fv "${i}" "${i}.sig"
				;;
		esac
	done
	cd $olddir
	[ "x$keep" = "xno" ] && rm -f "${pkgfile}" "${pkgfile}.sig"
}

for i in $@; do
	updatepkg "$i"
done
