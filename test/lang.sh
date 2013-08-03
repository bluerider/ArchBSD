#!/usr/bin/env bash

lang() {
	local mesg=$1; shift
        lang_msg=$(grep $mesg lang/$LANGUAGE | awk -F : '{print $2}') 
	dialog --msgbox "$lang_msg" 6 70
}

LANGUAGE=$(dialog --title "A dialog Menu Example" \
	--menu "Please select a language:" 0 0 2 \
	1 "English" \
	2 "German" \
	--stdout)

case $LANGUAGE in
	1)
		LANGUAGE="English"
		;;
	2)
		LANGUAGE="German"
		;;
esac
	
lang 1
lang 2


