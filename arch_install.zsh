#!/bin/bash
set -x

failexit () {
    echo "Fail"; exit
}

# echo -n "Luks2 volume password": 
# read -s vol_pass
# echo $vol_pass

vol_pass=$1

# Kernel modules
modprobe dm-mod
modprobe dm-crypt

# Disk
umount -q /mnt/boot
umount -q /mnt
dd if=/dev/urandom of=/dev/sda bs=1M count=1024

parted /dev/sda -s -- mklabel msdos
parted /dev/sda -s -- mkpart primary 512B 256MiB
parted /dev/sda -s -- mkpart primary 256MiB 100%

# Create crypto volume
echo -n $vol_pass | cryptsetup -q luksFormat --type luks2 --pbkdf-memory 256 /dev/sda2 -d -
echo -n $vol_pass | cryptsetup open /dev/sda2 cryptlvm
sleep 1 && [[ -L /dev/mapper/cryptlvm ]] || failexit

# LVM
pvcreate /dev/mapper/cryptlvm
vgcreate vg_arch /dev/mapper/cryptlvm
lvcreate -L 512M -n swap vg_arch
lvcreate -l 100%free -n root vg_arch

# FS
mkfs.ext2 /dev/sda1
mkfs.ext4 /dev/vg_arch/root
mkswap /dev/vg_arch/swap
swapon /dev/vg_arch/swap

# Mounts
mount /dev/vg_arch/root /mnt/
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot/

# Pacman
sed -i 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads\ =\ 5/' /etc/pacman.conf
cat << EOF > /etc/pacman.d/mirrorlist
Server = https://mirror.yandex.ru/archlinux/\$repo/os/\$arch
Server = http://mirror.rol.ru/archlinux/\$repo/os/\$arch
Server = https://mirror.rol.ru/archlinux/\$repo/os/\$arch
Server = http://mirror.truenetwork.ru/archlinux/\$repo/os/\$arch
Server = http://mirror.yandex.ru/archlinux/\$repo/os/\$arch
Server = http://archlinux.zepto.cloud/\$repo/os/\$arch
EOF

# Packages
pacstrap /mnt linux-lts base base-devel lvm2 mkinitcpio grub openssh nano docker docker-compose

# fstab
genfstab -pU /mnt >> /mnt/etc/fstab

curl https://raw.githubusercontent.com/Acidter/archluks2/master/system_prepare.sh > /mnt/root/system_prepare.sh
chmod +x /mnt/root/system_prepare.sh
arch-chroot /mnt /root/system_prepare.sh

rm -- "$0"
