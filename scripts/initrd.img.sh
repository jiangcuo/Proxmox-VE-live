#!/bin/bash
arch="amd64"
release="bullseye"
rootfssrc="/tmp/rootfssrc"
localfile="/root/local"
pve_initrd=`ls /tmp/boot/initrd*|head -n 1`

mv $rootfssrc/boot /tmp
rm /tmp/boot/initrd.img.gz 
rm /tmp/boot/initrd.img
cp $pve_initrd /tmp/boot/initrd.img.gz 
mkdir /tmp/initrd
cd /tmp/initrd
gzip -d /tmp/boot/initrd.img.gz 
cpio -idmv < /tmp/boot/initrd.img
cp $localfile /tmp/initrd/scripts/
rm $pve_initrd
find . | cpio -o -H newc | gzip > $pve_initrd
mkdir /tmp/iso
mkdir /tmp/iso/{.installer,.installer-mp,.workdir,.base}
