#!/bin/bash

SCRIPT_DIR="$( dirname "$0" )"
source $SCRIPT_DIR/common.sh

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
update
install debootstrap util-linux arch-install-scripts dosfstools e2fsprogs btrfs-progs nano parted

# partition disk
source /installer/disk.sh

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
cp "$SCRIPT_DIR/common.sh" /mnt/common.sh
cp "$SCRIPT_DIR/install.sh" /mnt/install.sh
cp "$SCRIPT_DIR/programs.sh" /mnt/programs.sh
chmod +x /mnt/*.sh
cp "$SCRIPT_DIR/config/pipewire.conf" /mnt/pipewire.conf

echo "chrooting to /mnt"
echo "in order to continue installation, run 'bash /install.sh' from the chroot environment."

arch-chroot /mnt

echo "exitted out of chroot."

# cleanup
echo "cleaning up..."
source "$SCRIPT_DIR/cleanup.sh"
