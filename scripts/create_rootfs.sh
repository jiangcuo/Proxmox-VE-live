#!/bin/bash
#create rootfs
arch="amd64"
release="bullseye"
targetdir="/targetdir"
targetdirsqu="/root/pve-base.squ"

prepare_rootfs_mount(){
mount -t proc /proc  $targetdir/proc
mount -t sysfs /sys  $targetdir/sys
mount -o bind /dev  $targetdir/dev
mount -o bind /dev/pts  $targetdir/dev/pts
}

prepare_rootfs_umount(){
umount -l $targetdir/proc
umount -l $targetdir/sys
umount -l $targetdir/dev/pts
umount -l $targetdir/dev
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
	echo "allow root login with openssh"
	sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' $targetdir/etc/ssh/sshd_config
	sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' $targetdir/etc/ssh/sshd_config
	sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords yes/' $targetdir/etc/ssh/sshd_config
}

modify_hostname(){
	echo "modify hostname"
    cat << EOF > $targetdir/etc/hosts
127.0.0.1 localhost.localdomain localhost
10.10.10.10 pve.testlive.com pve
#The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF
	echo "pve"> $targetdir/etc/hostname
}

modify_proxmox_boot_sync(){
	sed -i 's/^/#&/' $targetdir/etc/initramfs/post-update.d//proxmox-boot-sync
	sed -i '1c \#!/bin/bash' $targetdir/etc/initramfs/post-update.d//proxmox-boot-sync
}

restore_proxmox_boot_sync(){
	sed -i 's/^#//' $targetdir/etc/initramfs/post-update.d//proxmox-boot-sync
	sed -i '1c \#!/bin/bash' $targetdir/etc/initramfs/post-update.d//proxmox-boot-sync
}

debconfig_set(){
	echo "locales locales/default_environment_locale select en_US.UTF-8" >> $targetdir/tmp/debconfig.txt
	echo "locales locales/locales_to_be_generated select en_US.UTF-8 UTF-8" >> $targetdir/tmp/debconfig.txt
	echo "samba-common samba-common/dhcp boolean false" >> $targetdir/tmp/debconfig.txt
	echo "samba-common samba-common/workgroup string WORKGROUP" >> $targetdir/tmp/debconfig.txt
	echo "postfix postfix/main_mailer_type select No configuration" >> $targetdir/tmp/debconfig.txt
}
debconfig_write(){
	chroot $targetdir debconf-set-selections /tmp/debconfig.txt
	chroot $targetdir rm /tmp/debconfig.txt
}


modify_network(){
cat << EOF > $targetdir/etc/network/interfaces 
auto lo
iface lo inet loopback
EOF
}

#create rootfs
if [ ! -d "$targetdir" ]; then
    mkdir $targetdir
else
    if [ -z `is_empty_dir $targetdir` ];then
    echo "$targetdir is empty,do nothing"
    else
    rm $targetdir/* -rootfs
    fi
fi



apt install debootstrap squashfs-tools -y
debootstrap --arch=$arch $release $targetdir https://mirrors.ustc.edu.cn/debian/ ||errlog "rootfs create failed"


if [ $release = "buster" ];then
cat << EOF > $targetdir/etc/apt/sources.list
deb http://mirrors.ustc.edu.cn/debian/ buster main contrib non-free
deb http://mirrors.ustc.edu.cn/debian/ buster-updates main contrib non-free
deb http://mirrors.ustc.edu.cn/debian/ buster-backports main contrib non-free
deb http://mirrors.ustc.edu.cn/debian-security/ buster/updates main contrib non-free
deb https://mirrors.ustc.edu.cn/proxmox/debian/  buster pve-no-subscription
EOF
wget https://mirrors.ustc.edu.cn/proxmox/debian/proxmox-ve-release-6.x.gpg -O $targetdir/etc/apt/trusted.gpg.d/proxmox-release-buster.gpg 
else
cat << EOF > $targetdir/etc/apt/sources.list
deb http://mirrors.ustc.edu.cn/debian/ bullseye main contrib non-free
deb http://mirrors.ustc.edu.cn/debian/ bullseye-updates main contrib non-free
deb http://mirrors.ustc.edu.cn/debian/ bullseye-backports main contrib non-free
deb http://mirrors.ustc.edu.cn/debian-security/ bullseye-security main contrib non-free
deb https://mirrors.ustc.edu.cn/proxmox/debian/ bullseye pve-no-subscription
EOF
wget https://mirrors.ustc.edu.cn/proxmox/debian/proxmox-release-bullseye.gpg -O $targetdir/etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg 
fi


modify_hostname
prepare_rootfs_mount || errlog "rootfs env mount  failed"

debconfig_set
debconfig_write
chroot $targetdir apt update 
LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot $targetdir  apt install proxmox-ve -y  bash-completion ksmtuned wget curl vim iputils-* locales || echo  "proxmox-ve install  failed but ok"
modify_proxmox_boot_sync
#fix kernel postinstall error
mv $targetdir/var/lib/dpkg/info/pve-kernel-*.postinst ./
#fix ifupdown2 error
mv $targetdir/var/lib/dpkg/info/ifupdown2.postinst  ./
LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot $targetdir dpkg --configure -a
mv ./ifupdown2.postinst $targetdir/var/lib/dpkg/info/ifupdown2.postinst
mv ./pve-kernel-*.postinst $targetdir/var/lib/dpkg/info/
restore_proxmox_boot_sync

#if you wan't save your pve-cluster config. you can mount your dev to /var/lib/pve-cluster
#defualt is mount disk which label is pvedata and type is vfat.
systemdpath="$targetdir/etc/systemd/system/var-lib-pve\\x2dcluster.mount"
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
mkdir $targetdir/etc/systemd/system/var-lib-pve\\x2dcluster.d
cat > $targetdir/etc/systemd/system/var-lib-pve\\x2dcluster.d/timeout.conf <<EOF
[Mount]

TimeoutSec=5s

EOF
#fix upload cdrom error
chmod 1777 $targetdir/var/tmp

# copy rc.local
cp ../etc/* $targetdir/etc/
chmod +x $targetdir/etc/rc.local
chmod +x $targetdir/etc/pvelive/*


# enable sshd
enable_ssh

prepare_rootfs_umount

