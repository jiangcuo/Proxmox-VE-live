#!/bin/bash
#on linux kernel 5,if linux cmdline contain the hostname=xx ,the initramfs will echo it to /root/etc/hosts
#So we use HOSTNAME instead hostname
HOSTNAME=`sed "s/ /\n/g" /proc/cmdline |grep HOSTNAME`
DN=`sed "s/ /\n/g" /proc/cmdline |grep DN`
if [ ! -z $HOSTNAME ];then
	export $HOSTNAME
	echo "define the hostname,do config hostname"
	echo $HOSTNAME >/etc/hostname
    sed -i "s/pve/$HOSTNAME/g" /etc/hosts
	hostnamectl set-hostname $HOSTNAME
fi

if [ ! -z $DN ];then
	export $DN
	echo "define the dn,do config dn"
	sed -i "s/testlive.com/$DN/g" /etc/hosts
fi

exit 0