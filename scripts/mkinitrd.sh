#!/bin/bash
#pwd={cdrom}/boot/
livepath="/root/Proxmox-VE-live/"
bootpwd=`pwd`
mkdir initrd
for i in `ls initrd*img`;
do
echo "$i progress"
cd $bootpwd
cp $i initrd/$i.gz
cd initrd
gzip -d $i.gz
mkdir initrd
cd initrd
echo "uncpio $i"
cpio -idm <../$i
echo "copy local"
cp $livepath/local scripts/
chmod +x scripts/local
echo "create new initrd"
find . | cpio -o -H newc | gzip > ../../$i
cd ..
rm initrd -rf
done
rm $bootpwd/initrd -rf