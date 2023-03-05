#!/bin/bash
diysh=`sed "s/ /\n/g" /proc/cmdline |grep diysh`

if [ ! -z $diysh ];then
	if [ ! -h /dev/disk/by-label/diysh ];then
		echo  "net disk not exit"
		exit 1;
	fi
	mkdir /tmp/diysh 
	mount /dev/disk/by-label/diysh  /tmp/diysh
	for mountscripts in `ls /tmp/diysh/*.sh`;do
		bash $mountscripts &
	done
fi

exit 0