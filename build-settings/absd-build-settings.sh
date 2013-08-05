#!/bin/sh
# Put this file here: /etc/archbsd-build.conf
# and modify it as needed

#cachedir=/var/cache/pacman/pkg

# DO NOT USE $HOME unless you want stuff to end up in /root
# These 2 lines needs to be fixed and uncommented
#abstree=/home/wry/Sources/ArchBSD
#buildtop=/home/wry/ABSD-Build

# These can be changed if necessary
#package_output=${buildtop}/output
#builder_bashrc=${buildtop}/bashrc
#setup_script=${buildtop}/setup_root
#prepare_script=${buildtop}/prepare_root
