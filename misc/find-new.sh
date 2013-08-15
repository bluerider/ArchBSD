#!/usr/bin/bash

repos=()
abstemp="/tmp/abs-temp"
absroot="."

usage () {
	echo "usage: $0 -r repo [-a abstemp] [-A absroot]"
	echo ""
	echo "    -r repo       Repo to scan, can be passed multiple times"
	echo "    -a abstemp    Temp-dir for abs (default: /tmp/abs-temp)"
	echo "                  (WARNING: WILL DELETE EXISTING COPY)"
	echo "    -A absroot    Root-dir to check (default: .)"
}

while getopts "h:r:a:A:" arg; do
	case $arg in
		h)
			usage
			exit 0
			;;
		r)
			repos+=($OPTARG)
			;;
		a)
			abstemp="$OPTARG"
			;;
		A)
			absroot="$OPTARG"
	esac
done

if [[ ${#repos} -eq 0 ]]; then
	usage
	exit 1
fi

echo "Checking repo(s): ${repos[@]}"

[[ -d "$abstemp" ]] && rm -rf "$abstemp"
mkdir -p "$abstemp"

echo "ABS-Root is \"${absroot}\""

echo "Syncing ABS into \"${abstemp}\"..."

ABSROOT="$abstemp" abs ${repos[@]} > /dev/null

if [[ $? ]]; then
	echo "ABS Synced"
else
	echo "Sync failed... Aborting"
	exit 1
fi

for dir in $(find ${absroot} -name "PKGBUILD" -type f); do
	name="$(echo $dir | awk -F "/" '{print $3}')"
	al_path=$(find "${abstemp}" -name "$name" -type d 2>&1)
	[[ ! -d ${al_path} ]] && continue
	al_file="${al_path}/PKGBUILD"
	al_ver=$(grep "pkgver=" "$al_file" | tr -d ' ')
	ab_ver=$(grep "pkgver=" "$dir" | tr -d ' ')
	if [[ "${al_ver}" != "${ab_ver}" ]]; then
		echo "Package-version differ: $name"
		echo " - ArchLinux: $al_ver"
		echo " - ArchBSD:   $ab_ver"
	fi
done
