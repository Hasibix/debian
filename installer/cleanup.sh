#!/bin/bash

SCRIPT_DIR="$( dirname "$0" )"
source $SCRIPT_DIR/common.sh

# --- checks ---
if [ "$(id -u)" -ne 0 ]; then
	echo "this script must be run as root"
	exit 1
fi

# --- functions ---

# prompt for swap if it wasn't set
prompt_swap_if_missing() {
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
}

# remove installer files from target
remove_temp_installer_files() {
	echo "removing temporary installer files..."
	rm -f /mnt/pipewire.conf
	rm -f /mnt/common.sh
	rm -f /mnt/install.sh
	rm -f /mnt/programs.sh
	echo "cleanup of temp files done."
}

# unmount everything
unmount_partitions() {
	echo "unmounting partitions..."
	swapoff "$swap" || true
	umount -R /mnt || true
	echo "done unmounting."
}

# --- main ---

prompt_swap_if_missing
remove_temp_installer_files
unmount_partitions

# done
echo "installation cleanup complete."

# prompt for reboot
read -p "would you like to reboot now? [y/N] " ans
ans=${ans:-n}

case "${ans,,}" in
	y|yes)
		echo "rebooting now…"
		sleep 3
		reboot
		;;
	*)
		echo "not rebooting."
		exit 0
		;;
esac
