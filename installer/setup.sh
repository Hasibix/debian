#!/bin/bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
	echo "this script must be run as root"
	exit 1
fi

# now check if it was invoked via sudo
if [ -n "${SUDO_USER:-}" ]; then
	echo "do not run this script with sudo; switch to root instead"
	exit 1
fi

# check if system is uefi
if [ ! -d /sys/firmware/efi ]; then
	echo "error: system is not booted in uefi mode."
	echo "this installer only supports uefi systems."
	exit 1
fi

# --- functions ---
prompt_partitions() {
	while true; do
		clear
		lsblk
		echo
		read -p "enter partition for BOOT: " boot
		read -p "enter partition for SWAP: " swap
		read -p "enter partition for DATA: " data

		# make sure none are empty
		if [ -z "$boot" ] || [ -z "$swap" ] || [ -z "$data" ]; then
			echo "boot, swap, and data partitions cannot be empty. please try again."
			read -n1 -r -p "press any key to continue..."
			continue
		fi

		read -p "enter filesystem for DATA (ext4, btrfs, xfs, etc.): " fs
		if [ -z "$fs" ]; then
			fs="btrfs"
		fi

		read -p "enter label for DATA partition (default: rootfs): " label
		if [ -z "$label" ]; then
			label="rootfs"
		fi

		# all required values are set, exit loop
		break
	done
}

prompt_debootstrap_stability() {
	clear
	read -p "do you want stable packages? [Y/n] " ans
	ans=${ans:-y}

	# normalize to lowercase
	case "${ans,,}" in
		y|yes)
			echo "using stable"
			use_stable=true
			;;
		n|no)
			echo "using unstable (sid)"
			use_stable=false
			;;
		*)
			echo "invalid choice, defaulting to stable"
			use_stable=true
			;;
	esac
}

# --- main ---
# install deps
apt update -y
apt install -y debootstrap arch-install-scripts dosfstools e2fsprogs btrfs-progs nano parted

# partition disk
. /installer/disk.sh

if [ -z "$boot" ] || [ -z "$swap" ] || [ -z "$data" ]; then
	echo "something went wrong with partitioning disks. please try again."
	exit 0
fi

# mount partitions
echo "mounting partitions..."
mkdir -p /mnt
mount "$data" /mnt
mount -m "$boot" /mnt/boot/efi
swapon "$swap"
echo "done"

# debootstrap
prompt_debootstrap_stability
if [ "$use_stable" = true ]; then
	echo "setting up for stable packages..."
	debootstrap stable /mnt https://deb.debian.org/debian
else
	echo "setting up for unstable (sid)..."
	debootstrap sid /mnt https://deb.debian.org/debian
fi

# fstab
echo "generating fstab for /mnt"
genfstab -U /mnt | tee /mnt/etc/fstab

# chroot
cp /installer/install.sh /mnt/install.sh
chmod +x /mnt/install.sh
cp /config/pipewire.conf /mnt/pipewire.conf

echo "chrooting to /mnt"
echo "in order to continue installation, run 'bash /install.sh' from the chroot environment."

arch-chroot /mnt

echo "exitted out of chroot."

# cleanup
rm /mnt/pipewire.conf
rm /mnt/install.sh

if [ -z "${swap:-}" ]; then
	while true; do
		clear
		lsblk
		read -p "which one is your swap partition? " swap
		
		if [ -z "$swap" ]; then
			echo "swap partition cannot be empty. please try again."
			read -n1 -r -p "press any key to continue..."
			continue
		fi
	
		break
	done
fi

echo "unmounting boot, swap and data partitions..."
swapoff "$swap"
umount -r /mnt

echo "done."
read -p "would you like to reboot now? [y/N] " ans
ans=${ans:-n}

case "${ans,,}" in
	y|yes)
		echo "rebooting in 3 seconds (make sure to boot to your disk, not the live environment)"
		sleep 3
		reboot
		;;
	*)
		echo "will not reboot"
		echo "once you're done using the live environment, you can reboot by running 'reboot'"
		exit 0
		;;
esac
