#!/bin/bash
hostname=`sed "s/ /\n/g" /proc/cmdline |grep hostname`
dn=`sed "s/ /\n/g" /proc/cmdline |grep dn`
if [ ! -z $hostname ];then
	export $hostname
	echo "define the hostname,do config hostname"
	echo $hostname >/etc/hostname
    sed -i "s/pve/$hostname/g" /etc/hosts
	hostnamectl set-hostname $hostname
fi

if [ ! -z $dn ];then
	export $dn
	echo "define the dn,do config dn"
	sed -i "s/testlive.com/$dn/g" /etc/hosts
fi
systemctl restart pvebanner.service 
exit 0