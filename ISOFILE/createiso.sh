#!/bin/bash
xorriso -as mkisofs -V 'PVE' \
--modification-date='2022112209341100' \
--grub2-mbr --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt,zero_apm:'/mnt/pve/nfs/template/iso/proxmox-ve_7.3-1.iso' \
--protective-msdos-label \
-partition_cyl_align off \
-partition_offset 0 \
-partition_hd_cyl 67 \
-partition_sec_hd 32 \
-apm-block-size 2048 \
-hfsplus \
-efi-boot-part --efi-boot-image \
-c 'boot/boot.cat' \
-b 'boot/grub/i386-pc/eltorito.img' \
-no-emul-boot \
-boot-load-size 4 \
-boot-info-table \
--grub2-boot-info \
-eltorito-alt-boot \
-e 'efi.img' \
-no-emul-boot \
-boot-load-size 5760 \
.