#!/bin/bash
network=`sed "s/ /\n/g" /proc/cmdline |grep network`

errlog(){
	if [ $? != 0 ];then
		echo $1
		exit 0;
	fi
}


if [ ! -z $network ];then
	echo "define the network,do config network"
	if [ ! -h /dev/disk/by-label/pvenet ];then
		echo  "net disk not exit"
		exit 0;
	fi
	netmount=`grep  '/etc/network' /proc/mounts`
	if [ -z "$netmount" ];then
		mount -t auto /dev/disk/by-label/pvenet /etc/network || errlog "mount diskerror"
		systemctl stop dhcpcd
		systemctl restart networking
		ifreload -a
		ipaddress=`grep address /etc/network/interfaces|awk '{print $2}'|cut -d "/" -f1|head -n 1`
		sed -i "s/10.10.10.10/$ipaddress/g" /etc/hosts
	else
		echo "network has mounted ,do nothing"
		exit 0;
	fi
else
	echo "netconfig is not right"
	exit 0;
fi

exit 0