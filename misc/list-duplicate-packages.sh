#!/bin/sh

# list packages
# strip the version number
# sort
# and only show duplicates

if [ $# -eq 1 ]; then
  ls "$1"/*.pkg.tar.xz |pcregrep -o '^.*?(?=-\d)' |sort |uniq -d
else
  ls *.pkg.tar.xz |pcregrep -o '^.*?(?=-\d)' |sort |uniq -d
fi
