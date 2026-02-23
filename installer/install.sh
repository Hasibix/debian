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

# --- functions ---
prompt_timezone() {
	while true; do
		clear
		find /usr/share/zoneinfo -type f \
			! -path '*/posix/*' \
			! -path '*/right/*' \
			| sed 's|/usr/share/zoneinfo/||' \
			| sort \
			| column \
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
		hwclock --systohc
		echo "timezone set to $zone"
		break
	done
}

set_password() {
	local user="$1"

	if [ -z "$user" ]; then
		echo "no username provided"
		return 1
	fi

	while true; do
		read -s -p "enter new password for $user: " pass
		echo
		read -s -p "confirm password for $user: " pass2
		echo

		if [ "$pass" != "$pass2" ]; then
			echo "passwords do not match, try again"
			continue
		fi

		if echo "$user:$pass" | chpasswd; then
			echo "password updated successfully for $user"
			unset pass pass2
			break
		else
			echo "failed to set password for $user, try again"
		fi
	done
}

prompt_shell() {
	while true; do
		echo "which shell do you want to set as default for $username?"
		read -p "[Bash/sh/zsh/fish] " shell
		shell=${shell:-bash}
		case "${shell,,}" in
			b|bash|/bin/bash)
				echo "keeping bash as default shell"
				break
				;;
			s|sh|/bin/sh)
				echo "setting sh as the default shell"
				usermod -s /bin/sh "$username"
				break
				;;
			z|zsh|/bin/zsh)
				echo "setting zsh as the default shell"
				usermod -s /bin/zsh "$username"
				break
				;;
			f|fish|/bin/fish)
				echo "setting fish as the default shell"
				usermod -s /bin/fish "$username"
				break
				;;
			*)
				echo "invalid choice, please try again."
				continue
				;;
		esac
	done
}

prompt_gui() {
	while true; do
		read -p "do you want to install setup gui? [Y/n] " ans
		ans=${ans:-y}
		case "${ans,,}" in
					y|yes)
						echo "will set up gui"
						setup_gui=true
						break
						;;
					n|no)
						echo "will not setup gui"
						setup_gui=false
						break
						;;
					*)
						echo "invalid choice. please try again."
						continue
						;;
		esac
	done
}

prompt_audio() {
	while true; do
		read -p "do you want to install setup audio? [Y/n] " ans
		ans=${ans:-y}
		case "${ans,,}" in
					y|yes)
						echo "will set up audio"
						setup_audio=true
						break
						;;
					n|no)
						echo "will not setup audio"
						setup_audio=false
						break
						;;
					*)
						echo "invalid choice. please try again."
						continue
						;;
		esac
	done
}

user_cargo() {
	local username="$1"
	shift
	su - "$username" -c '
		. "$HOME/.cargo/env"
		cargo "$@"
	' -- "$@"
}

# --- main ---
apt update -y
apt install -y e2fs-progs btrfs‑progs linux-image-amd64

# locales
apt -y install nano locales
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
apt -y install grub-efi-amd64
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
usermod -aG video "$username"
groupadd -f audio
usermod -aG audio "$username"

# cli and system tools 
echo "installing cli tools"
apt install -y wget xz-utils unzip 7zip sudo util-linux openssh-server neovim curl zsh fish network-manager
systemctl enable NetworkManager

# shell
prompt_shell

# dev tools
echo "installing dev tools"
apt install -y git build-essential
su - "$username" -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
echo ". \"/home/$username/.cargo/env\"" >> /home/$username/.profile

user_cargo "$username" install cargo-binstall

# gui stuff
prompt_gui
if [ "$setup_gui" = true ]; then
	apt install -y lightdm lightdm-gtk-greeter
	dpkg-reconfigure lightdm
	systemctl enable lightdm
	mkdir -p /etc/lightdm/lightdm.conf.d
	tee /etc/lightdm/lightdm.conf.d/01-users.conf > /dev/null <<EOF
[Seat:*]
greeter-hide-users=false

EOF
	apt install -y xorg xsel sxwm \
	feh picom polybar rofi \
	xfce4-power-manager \
	xfce4-clipman redshift thunar alacritty \
	thunar-archive-plugin thunar-media-tags-plugin thunar-volman \
	pavucontrol
	# TODO: add more programs that i use

	# pipewire
	apt install -y pipewire-audio wireplumber
	mkdir -p /home/$username/.config/pipewire
	cp -r /pipewire.conf /home/$username/.config/pipewire/pipewire.conf
	su - "$username" -c "systemctl --user enable pipewire pipewire-pulse wireplumber"
fi

# dotfiles
# TODO: download my dotfiles

# gaming tools
user_cargo "$username" install ran-launcher
# TODO: install wine-staging, umu-launcher and legendary

# finish
echo "finished installing debian!"
echo "now exit out of chroot to let setup.sh continue"
read -n1 -r -p "press any key to continue..."
exit 0
