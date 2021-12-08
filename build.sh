#!/bin/bash
# Based on https://blog.stefan-koch.name/2020/05/31/automation-archlinux-qemu-installation

src="https://mirror.rackspace.com/archlinux/iso/2021.11.01/archlinux-bootstrap-2021.11.01-x86_64.tar.gz"

archive=image/archlinux.tar.gz
image=image/image.raw
mountpoint=image/arch

if [[ ! -f $archive ]]; then
    wget $src -O $archive
fi

mkdir -p $mountpoint
mkdir -p ssh

qemu-img create -f raw $image 20G

loop="$(sudo losetup --show -f -P $image)"
sudo mkfs.ext4 "$loop"
sudo mount "$loop" "$mountpoint"
sudo tar zxf "$archive" -C "$mountpoint" --strip-components 1

key="$(cat ssh/qemu_ssh.pub)"

sudo "$mountpoint/bin/arch-chroot" "$mountpoint" /bin/bash <<EOL
set -v

echo 'Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch' >> /etc/pacman.d/mirrorlist

pacman-key --init
pacman-key --populate archlinux

pacman -Syu --noconfirm
pacman -S --noconfirm base linux linux-firmware mkinitcpio openssh kitty-terminfo dhcpcd
systemctl enable sshd dhcpcd

# Standard Archlinux Setup
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
echo arch-qemu > /etc/hostname
echo -e '127.0.0.1  localhost\n::1  localhost' >> /etc/hosts

mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
echo -e "[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin root -s %I 115200,38400,9600 vt102" > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf

echo -e "share.1\t/mnt\tvirtiofs\trw,_netdev\t0\t0" >> /etc/fstab

mkdir /root/.ssh
echo "$key" > /root/.ssh/authorized_keys

# Create an initramfs without autodetect, because this breaks with the
# combination host/chroot/qemu
linux_version=\$(ls /lib/modules/ | sort -V | tail -n 1)
mkinitcpio -c /etc/mkinitcpio.conf -S autodetect --kernel \$linux_version -g /boot/initramfs-linux-custom.img

echo 'root:root' | chpasswd
EOL

cp "$mountpoint/boot/vmlinuz-linux" image/
cp "$mountpoint/boot/initramfs-linux-custom.img" image/

sudo "$mountpoint/bin/arch-chroot" "$mountpoint" /bin/bash <<EOL
pacman -Rs --noconfirm linux linux-firmware mkinitcpio
rm -r /var/cache/pacman/pkg
rm -r /boot
EOL

sudo umount "$mountpoint"
sudo losetup -d "$loop"
qemu-img convert -f raw -O qcow2 "$image" image/image.qcow2
rm image/image.raw
