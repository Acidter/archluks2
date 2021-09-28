#!/bin/bash

failexit () {
    echo "Fail"; exit
}

# Kernel modules
modprobe dm-mod
modprobe dm-crypt

# Disk
parted /dev/sda -s -- mklabel msdos
parted /dev/sda -s -- mkpart primary 512B 256MiB
parted /dev/sda -s -- mkpart primary 256MiB 5369MB

# Create crypto volume
cryptsetup -y luksFormat --type luks2 --pbkdf-memory 256 /dev/sda2
[[ -f /dev/mapper/cryptlvm ]] || failexit
cryptsetup open /dev/sda2 cryptlvm

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

rm -- "$0"
