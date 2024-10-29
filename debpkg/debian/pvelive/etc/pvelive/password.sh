#!/bin/bash
password=`sed "s/ /\n/g" /proc/cmdline |grep password`

if [ ! -z $password ];then
	export $password
	echo "define the password,do config password"
	echo "root:$password" |chpasswd
fi

exit 0