#!/bin/bash
set -x

# Time and date
timedatectl set-ntp true
timedatectl set-timezone Europe/Moscow

# Kernel
sed -i '/ *#/d; /^ *$/d' /etc/mkinitcpio.conf
sed -i 's/filesystems/encrypt lvm2 filesystems/' /etc/mkinitcpio.conf

mkinitcpio -p linux-lts

# Bootloader
grub-install /dev/sda --force
crypto_disk_uuid=$(blkid /dev/sda2 | awk -F '"' '{print $2}')
sed -i "s/GRUB_CMDLINE_LINUX\=\"\"/GRUB_CMDLINE_LINUX\=\"cryptdevice\=UUID\=${crypto_disk_uuid}\:cryptlvm\ root\=\/dev\/vg_arch\/root\"/" /etc/default/grub
sed -i 's/#GRUB_ENABLE_CRYPTODISK\=y/GRUB_ENABLE_CRYPTODISK\=y/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Network
cat << EOF > /etc/systemd/network/wired.network
[Match]
Name=*

[Network]
DHCP=ipv4
EOF

systemctl enable systemd-networkd

# DNS
cat << EOF > /etc/systemd/resolved.conf
[Resolve]
DNSSEC=false
FallbackDNS=8.8.4.4 9.9.9.9
DNS=1.1.1.1 8.8.8.8
EOF

systemctl enable systemd-resolved

# SSH
sed -i 's/#Port 22/Port 53522/' /etc/ssh/sshd_config
systemctl enable sshd

mkdir /root/.ssh
cat << EOF > /root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCedELZqonSIpvFYSrI3LAsM1tDBGjHeYreKbmUGfW40u3VqjUMs2GXB0EXriIfy7bl4Setvh7zvw7yAcuiAv9psOXVy1IDzJACTEbeNa0LmxhshVGqL5PBKpusrUR6ucTRCgChA0SJbxlDQsLcTy+EIB91/w6BaCoLyj7bbw33qgrHkphBDDznDRABBIQzsA5XaX5CetoTkhmg+ksZEVE4e1aHUgByw89TrU+bJmfNssySUoz6ToVZj3sH7hI9/7r7r1uJqEdbx8AphoDQlzVMBwoNZlMnYjxh/hSui+PZrR9daKVPnbzkzW7wDyMm4ySS41kSY8I+Qk3+4fXfnmBOE7Q+tL2oRLrhUZ8pxYO74GrW1c0ICKwR90ceHoP3W6qMhv8Dcn79x16x4CWtJ8fG3IB6kKOF1wjE+TcjerIRizSfhJKHHQ/sEf26joZP/+ND5KJ7xV3Y/c5qrJ/3No+GntRMS/SAuPpvQMeqF93w4NEJQ3pxeGaRGl9k2Yh/Pxc=
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCn28fK0KNuT9UIPE/EQMqpcA/LClZCyYLx4uXf0e5OeBFOXDHTW96f9pQdl8Hv9rcZ2Mx7aGC3x1+SqlqGWaAhYZNax5jrnVUrNWPWVtYHCZf8K1sQ1VGryAFHkoNuShfZw03aMMSFe9gSoi30YzJmjBhBlcvXYP+G0X/RE4tVr99SFIi9mL1Ox3izAQ/OUmDVJu75nqDf4xmiQ30B3XVGOJeoME1lp6VoHlsEhIFND+cRtP4rBLNihWm+phJhnqPBI/1XpF2LqoA1rtrKvOfbz6iOt2xIw+rBtda/XWYygB7EqoD+WlJAj+ORCyY1Wnowi3cf80clETsgvkEQjanR/7k1E+y+xb2xOYOXKdlIHfzwrImwoXFkcHuaDx1QgdcjD5e4+4XZIvC7Gk3iDgZTjP88jnSgYyQ68v9Cv6bCOUDIrGn8uDB2dTgw3mmEC0PUmdOnHli63qIaM5yYwfMqCj7D6LRKhjFnIb46MmHmfSFmsBU+4yqxtA8Rh3bnSI0=
EOF
chmod 0700 /root/.ssh
chmod 0600 /root/.ssh/authorized_keys

# Clean
rm -rfv /var/cache/pacman/pkg/*

rm -- "$0"
