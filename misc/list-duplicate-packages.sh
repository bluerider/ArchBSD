#!/bin/sh

# list packages
# strip the version number
# sort
# and only show duplicates
ls *.pkg.tar.xz |pcregrep -o '^.*?(?=-\d)' |sort |uniq -d
