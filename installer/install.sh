#!/bin/bash

SCRIPT_DIR="$( dirname "$0" )"
source $SCRIPT_DIR/common.sh

# --- functions ---
prompt_timezone() {
	while true; do
		clear
		find /usr/share/zoneinfo -type f \
			! -path '*/posix/*' \
			! -path '*/right/*' \
			| sed 's|/usr/share/zoneinfo/||' \
			| sort \
			| less

		read -p "select your timezone: " zone

		# if empty, try again
		if [ -z "$zone" ]; then
			echo "timezone cannot be empty, try again"
			sleep 1
			continue
		fi

		# check if that file actually exists
		if [ ! -f "/usr/share/zoneinfo/$zone" ]; then
			echo "timezone '$zone' does not exist, try again"
			sleep 1
			continue
		fi

		# valid, link it
		ln -sf "/usr/share/zoneinfo/$zone" /etc/localtime
		echo "timezone set to $zone"
		break
	done
}

# --- main ---
update
install e2fsprogs btrfs-progs util-linux linux-image-amd64

# locales
install nano locales
echo "opening /etc/locale.gen using nano"
echo "please uncomment the locales you prefer"
echo "then save and quit"
read -n1 -r -p "press any key to continue..."
nano /etc/locale.gen
echo "generating locales using locale-gen"
locale-gen

# timezone
prompt_timezone
read -p "choose a hostname for your computer: " hostname
echo "$hostname" > /etc/hostname
echo "127.0.1.1	$hostname" >> /etc/hosts

# grub
echo "installing grub"
install grub-efi-amd64
grub-install --target=x86_64-efi --efi-directory=/boot/efi
update-grub

# user setup
set_password root

read -p "enter a name for your user account: " username
read -p "enter a display name for $username (leave empty for no display name): " displayname
if [ -z "$displayname" ]; then
	useradd -m -G sudo -s /bin/bash "$username"
else
	useradd -m -c "$displayname" -G sudo -s /bin/bash "$username"
fi

set_password "$username"

# enable i386
dpkg --add-architecture i386

# install programs
bash $SCRIPT_DIR/programs.sh "$username"

# finish
echo "finished installing debian!"
echo "now exit out of chroot to let setup.sh continue"
read -n1 -r -p "press any key to continue..."
exit 0
