#!/bin/bash

SCRIPT_DIR="$( dirname "$0" )"
source $SCRIPT_DIR/common.sh

# --- imports ---
SCRIPT_DIR="$( dirname "$0" )"
source $SCRIPT_DIR/common.sh

# --- functions ---
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

prompt_rd() {
	while true; do
		read -p "do you want to install remote desktop programs? [Y/n] " ans
		ans=${ans:-y}
		case "${ans,,}" in
					y|yes)
						echo "will set up remote desktop"
						setup_rd=true
						break
						;;
					n|no)
						echo "will not setup remote desktop"
						setup_rd=false
						break
						;;
					*)
						echo "invalid choice. please try again."
						continue
						;;
		esac
	done
}

prompt_gaming() {
	while true; do
		read -p "do you want to set up your system for gaming? [Y/n] " ans
		ans=${ans:-y}
		case "${ans,,}" in
					y|yes)
						echo "will install gaming dependencies"
						setup_gaming=true
						break
						;;
					n|no)
						echo "will not install gaming dependencies"
						setup_gaming=false
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
	as_user "$username" . "\$HOME/.cargo/env"\; cargo "$*"
}

# --- main ---
username=$1

# --- cli / system tools ---
echo "installing cli tools"
install wget curl jq \
    xz-utils unzip p7zip-full \
    sudo openssh-server \
    neovim network-manager
systemctl enable NetworkManager

# --- dev / build tools ---
echo "installing development and build tools"
install git build-essential

# rust toolchain
echo "install rust for $username"
as_user "$username" bash -lc "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile default"
echo ". \"/home/$username/.cargo/env\"" >> /home/$username/.profile

# python + pip
echo "installing python3 and pip3"
install python3 python3-pip pipx

# flatpak
echo "installing flatpak and adding flathub"
install flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# rust programs
echo "installing rust tools"
user_cargo "$username" install cargo-binstall
user_cargo "$username" binstall macchina
user_cargo "$username" install ran-launcher

# alternate shells
echo "installing alternative shells"
install zsh fish
prompt_shell

# --- gui setup ---
prompt_gui
if [ "$setup_gui" = true ]; then
	usermod -aG video "$username"
    echo "setting up gui environment"

    # display manager
    echo "installing display manager"
    install lightdm lightdm-gtk-greeter
    dpkg-reconfigure lightdm
    systemctl enable lightdm

    mkdir -p /etc/lightdm/lightdm.conf.d
    tee /etc/lightdm/lightdm.conf.d/01-users.conf > /dev/null <<EOF
	[Seat:*]
	greeter-hide-users=false

	EOF

    # xorg, window manager, and tools
    echo "installing desktop and gui utilities"
    install xorg sxwm \
        xsel feh picom \
        polybar rofi \
        xfce4-power-manager \
        redshift \
        pavucontrol

	# desktop portal
	install xdg-desktop-portal xdg-desktop-portal-gtk

	# clipboard manager
	install copyq copyq-plugins

	# media viewer/player
	install vlc qview

	# file manager
	install thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman

	# terminal
	install alacritty
	user_cargo "$username" binstall zellij

	# task manager
	flatpak install flathub io.missioncenter.MissionCenter

    # web browser
    echo "installing web browser"
    install extrepo
    extrepo enable librewolf
    update
    install librewolf

    # emoji picker
    echo "installing emoji picker"
    flatpak install io.github.vemonet.EmojiMart

	# code editor
	echo "installing code editor"
	as_user "$username" curl -f https://zed.dev/install.sh | sh

	# finish
	echo "finished setting up gui"
fi

prompt_audio
if [ "$setup_audio" = true ]; then
	groupadd -f audio
	usermod -aG audio "$username"

    # pipewire audio
    echo "installing pipewire"
    install pipewire-audio wireplumber
    mkdir -p /home/$username/.config/pipewire
    cp -r /pipewire.conf /home/$username/.config/pipewire/pipewire.conf

    as_user "$username" systemctl --user enable pipewire pipewire-pulse wireplumber

	# finish
	echo "finished setting up audio"
fi

prompt_rd
if [ "$setup_rd" = true ]; then
	# rustdesk
	echo "installing RustDesk"
	flatpak install flathub com.rustdesk.RustDesk

	# chrome remote desktop
	echo "installing Chrome Remote Desktop"
	crd_url="https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb"
	curl -L "$crd_url" -o /tmp/crd.deb
	dpkg -i /tmp/crd.deb
	install --fix-broken

	# finish
	echo "finished setting up remote desktop"
fi

# --- gaming ---
prompt_gaming
if [ "$setup_gaming" = true ]; then
	# wine
	echo "installing wine (staging)"
	dpkg --add-architecture i386
	install wget gnupg2

	mkdir -pm755 /etc/apt/keyrings
	wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
	wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources

	update
	install --install-recommends winehq-staging
	install wine32

	# umu launcher (proton)
	echo "installing umu (proton)"
	latest_tag=$(
			curl -s "https://api.github.com/repos/Open-Wine-Components/umu-launcher/releases/latest" \
			| jq -r .tag_name
	)
	if [ -z "$latest_tag" ]; then
	    echo "failed to fetch latest umu‑launcher release tag"
	    exit 1
	fi
	py3_umu_url="https://github.com/Open-Wine-Components/umu-launcher/releases/download/${latest_tag}/python3-umu-launcher_${latest_tag}-1_amd64_debian-13.deb"
	umu_url="https://github.com/Open-Wine-Components/umu-launcher/releases/download/${latest_tag}/umu-launcher_${latest_tag}-1_all_debian-13.deb"

	curl -L "$py3_umu_url" -o /tmp/umu/py3_umu.deb
	curl -L "$umu_url" -o /tmp/umu/umu.deb

	dpkg -i /tmp/umu/*.deb
	install --fix-broken

	rm -rf /tmp/umu

	# legendary (epic games)
	echo "installing legendary (epic games)"
	pipx install legendary-gl

	# finish
	echo "finished setting up gaming dependencies"
fi

# finish
echo "finished installing programs"
