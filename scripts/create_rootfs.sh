#!/bin/bash
#create rootfs
arch="amd64"
release="bullseye"
rootfssrc="/tmp/rootfssrc"
rootfssrcsqu="/root/pve-base.squ"

prepare_rootfs_mount(){
mount -t proc /proc  $rootfssrc/proc
mount -t sysfs /sys  $rootfssrc/sys
mount -o bind /dev  $rootfssrc/dev
mount -o bind /dev/pts  $rootfssrc/dev/pts
}

prepare_rootfs_umount(){
umount -l $rootfssrc/proc
umount -l $rootfssrc/sys
umount -l $rootfssrc/dev/pts
umount -l $rootfssrc/dev
}
is_empty_dir(){ 
    return `ls -A $1|wc -w`
}

errlog(){
	if [ $? != 0 ];then
		echo $1
		exit 0
	fi
}
enable_ssh(){
	echo "allow root login"
	sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' $rootfssrc/etc/ssh/sshd_config
	sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' $rootfssrc/etc/ssh/sshd_config
	sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords yes/' $rootfssrc/etc/ssh/sshd_config
}

modify_hostname(){
	echo "modify hostname"
    cat << EOF > $rootfssrc/etc/hosts
127.0.0.1 localhost.localdomain localhost
10.10.10.10 pve.pvelive.com pve
#The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF
	echo "pve"> $rootfssrc/etc/hostname
}

modify_proxmox_boot_sync(){
	sed -i 's/^/#&/' $rootfssrc/etc/initramfs/post-update.d//proxmox-boot-sync
	sed -i '1c \#!/bin/bash' $rootfssrc/etc/initramfs/post-update.d//proxmox-boot-sync
}

restore_proxmox_boot_sync(){
	sed -i 's/^#//' $rootfssrc/etc/initramfs/post-update.d//proxmox-boot-sync
	sed -i '1c \#!/bin/bash' $rootfssrc/etc/initramfs/post-update.d//proxmox-boot-sync
}


modify_network(){
cat << EOF > $rootfssrc/etc/network/interfaces 
auto lo
iface lo inet loopback
EOF
}

#create rootfs
if [ ! -d "$rootfssrc" ]; then
    mkdir $rootfssrc
else
    if [ is_empty_dir $rootfssrc ];then
    echo "$rootfssrc is empty,do nothing"
    else
    rm $rootfssrc/* -rootfs
    fi
fi



apt install debootstrap squashfs-tools -y
debootstrap --arch=$arch $release $rootfssrc https://mirrors.ustc.edu.cn/debian/ ||errlog "rootfs create failed"


if [ $release = "buster" ];then
cat << EOF > $rootfssrc/etc/apt/sources.list
deb http://mirrors.ustc.edu.cn/debian/ buster main contrib non-free
deb http://mirrors.ustc.edu.cn/debian/ buster-updates main contrib non-free
deb http://mirrors.ustc.edu.cn/debian/ buster-backports main contrib non-free
deb http://mirrors.ustc.edu.cn/debian-security/ buster/updates main contrib non-free
deb https://mirrors.ustc.edu.cn/proxmox/debian/  buster pve-no-subscription
EOF
wget https://mirrors.ustc.edu.cn/proxmox/debian/proxmox-ve-release-6.x.gpg -O $rootfssrc/etc/apt/trusted.gpg.d/proxmox-release-buster.gpg 
else
cat << EOF > $rootfssrc/etc/apt/sources.list
deb http://mirrors.ustc.edu.cn/debian/ bullseye main contrib non-free
deb http://mirrors.ustc.edu.cn/debian/ bullseye-updates main contrib non-free
deb http://mirrors.ustc.edu.cn/debian/ bullseye-backports main contrib non-free
deb http://mirrors.ustc.edu.cn/debian-security/ bullseye-security main contrib non-free
deb https://mirrors.ustc.edu.cn/proxmox/debian/ bullseye pve-no-subscription
EOF
wget https://mirrors.ustc.edu.cn/proxmox/debian/proxmox-release-bullseye.gpg -O $rootfssrc/etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg 
fi


modify_hostname
prepare_rootfs_mount || errlog "rootfs env mount  failed"
chroot $rootfssrc apt update 
LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot $rootfssrc  apt install proxmox-ve  ifenslave ifupdown -y || errlog "proxmox-ve install  failed"
modify_proxmox_boot_sync
LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot $rootfssrc dpkg --configure -a
restore_proxmox_boot_sync
#if you wan't save your pve-cluster config. you can mount your dev to /var/lib/pve-cluster
#defualt is mount disk which label is pvedata and type is vfat.

systemdpath="$rootfssrc/etc/systemd/system/var-lib-pve\\x2dcluster.mount"
cat << EOF > $systemdpath
[Unit]
Description=Mount System Backups Directory

[Mount]
What=/dev/disk/by-label/pvedata
Where=-var-lib-pve\\x2dcluster
Type=vfat
Options=defaults

[Install]
WantedBy=multi-user.target
EOF
mkdir $rootfssrc/etc/systemd/system/var-lib-pve\\x2dcluster.d
cat > /etc/systemd/system/var-lib-pve\\x2dcluster.d/timeout.conf <<EOF
[Mount]

TimeoutSec=5s

EOF

prepare_rootfs_umount

