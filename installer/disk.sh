#!/bin/bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
	echo "this script must be run as root"
	exit 1
fi

# now check if it was invoked via sudo
if [ -n "$SUDO_USER" ]; then
	echo "do not run this script with sudo; switch to root instead"
	exit 1
fi

# --- functions ---
prompt_disk() {
	while true; do
		clear
		lsblk
		echo
		read -p "select a disk to use (WARNING: this will ERASE all data on it): " disk
		if [ ! -b "$disk" ]; then
			echo "invalid disk device!"
			continue
		fi
		read -p "ARE YOU SURE you want to erase $disk? type YES (in all caps) to continue: " confirm
		if [ "$confirm" != "YES" ]; then
			echo "aborting."
			exit 1
		fi
		break
	done
}

prompt_swap_size() {
	local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
	# convert kB to MiB
	local mem_mib=$((mem_kb / 1024))

	read -p "enter desired swap size (press return to use RAM size: ${mem_mib}M): " swap_size
	if [ -z "$swap_size" ]; then
		swap_size="${mem_mib}M"
	fi
	swap_size_mib="${swap_size%M}"
}

prompt_partitions() {
	read -p "enter filesystem for DATA (ext4, btrfs, xfs, etc.) (default: btrfs): " fs
	if [ -z "$fs" ]; then
		fs="btrfs"
	fi

	read -p "enter label for DATA partition (default: rootfs): " label
	if [ -z "$label" ]; then
		label="rootfs"
	fi
}

# --- main ---
prompt_disk
if [[ "$disk" == *"nvme"* ]]; then
	boot="${disk}p1"
	swap="${disk}p2"
	data="${disk}p3"
else
	boot="${disk}1"
	swap="${disk}2"
	data="${disk}3"
fi
prompt_swap_size

# partitioning using parted (non-interactive)
# EFI: 1MiB to 1GiB
# SWAP: 1GiB to 1GiB + user-specified swap size
# ROOT/DATA: rest
parted -s "$disk" mklabel gpt
parted -s "$disk" mkpart primary fat32 1MiB 1GiB
parted -s "$disk" set 1 esp on

# calculate swap end
swap_start=1024
swap_end_mib=$((swap_start + swap_size_mib))
swap_end="${swap_end_mib}MiB"

parted -s "$disk" mkpart primary linux-swap "${swap_start}MiB" "$swap_end"
parted -s "$disk" mkpart primary "$fs" "$swap_end" 100%

clear
lsblk
prompt_partitions

# format partitions
mkfs.fat -F32 "$boot"
mkfs -t "$fs" -f -L "$label" "$data"
mkswap "$swap"

echo "all done!"
lsblk
read -n1 -r -p "press any key to continue..."
clear
export boot
export swap
export data
