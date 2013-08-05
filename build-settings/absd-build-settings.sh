#!/bin/sh
# Put this file here: /etc/archbsd-build.conf
# and modify it as needed

#cachedir=/var/cache/pacman/pkg

# DO NOT USE $HOME unless you want stuff to end up in /root
# These 2 lines might need to be edited for your needs :)
abstree=/var/absd/abstree
buildtop=/var/absd/buildtop

# These can be changed if necessary
#package_output=${buildtop}/output
#builder_bashrc=${buildtop}/bashrc
#setup_script=${buildtop}/setup_root
#prepare_script=${buildtop}/prepare_root
