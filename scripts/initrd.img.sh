#!/bin/bash
arch="amd64"
release="bullseye"
rootfssrc="/tmp/rootfssrc"
localfile="/root/scripts/local"

mv $rootfssrc/boot /tmp
pve_initrd=`ls /tmp/boot/initrd*|head -n 1`
cp $pve_initrd /tmp/boot/initrd.img.gz 
mkdir /tmp/initrd
cd /tmp/initrd
cpio -idmv < /tmp/boot/initrd.img
cp $rootfssrc/usr/lib/modules/5.15.83-1-pve/kernel/fs/overlayfs/overlay.ko ./
cp $localfile /tmp/initrd/scripts/
find . | cpio -o -H newc | gzip > $pve_initrd
mkdir /tmp/iso
mkdir /tmp/iso/{.installer,.installer-mp,.workdir,.base}