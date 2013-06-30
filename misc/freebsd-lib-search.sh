#!/usr/bin/bash

#########################################################
# Find all binary files in world that is linked against #
# a specific library. Useful for finding packages which #
# Need rebuild when splitting librarys from world       #                                   
#########################################################


match=$1
match2=$2
if [ -z $match ]; then
  echo 'Usage: freebsd-lib-search <libname> <Path to packages/'
  echo ''
  echo 'Find packages that depend on a given library.'
  echo 'E.G freebsd-lib-search libarchive.so.3 ~/packages/'
  echo ''
  exit 1
fi

#Set some default variables
cur_dir=`pwd`
tmp_dir="${cur_dir}/tmp/"
pac_path=$match2


if [ ! -d "$tmp_dir" ]; then
	mkdir "$tmp_dir"
fi

if [ -e "$cur_dir"/rebuild.txt ]; then
	echo "" > "$cur_dir"/rebuild.txt
fi


find_libs() {


for files in `find "$tmp_dir"/usr/{bin,sbin,lib} -type f -print0 | xargs -0 file | grep ELF | awk  -F ":" '{print $1}'`; do
	readelf -dW $files 2> /dev/null | sed -ne '/NEEDED/{s/^.*\[\(.*\)\]$/\1/;p;}' | grep $match > /dev/null 2>&1 >/dev/null;
	
if [ $? -eq 0 ]; then
        echo $packages Needs rebuild >> "$cur_dir"/rebuild.txt;
	break
fi

done
}

for packages in `ls $pac_path/*.x?`; do
	tar -xf "$packages" -C $tmp_dir

	find_libs
	#Clean tmp dir
        rm -rf "$tmp_dir"/*
done
