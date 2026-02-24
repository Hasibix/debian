#!/bin/bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
	echo "this script must be run as root"
	exit 1
fi

# check if system is uefi
if [ ! -d /sys/firmware/efi ]; then
	echo "error: system is not booted in uefi mode."
	echo "this installer only supports uefi systems."
	exit 1
fi

# --- functions ---
install() {
	apt install -y -qq "$@"
}

update() {
	apt update -y -qq
}

# --- main ---
url="https://github.com/Hasibix/debian/raw/refs/heads/main"

if ! command -v curl &> /dev/null; then
    echo "curl not found, installing..."
    update
    install curl
fi

mkdir -p /installer/config
curl -L "$url/installer/config/pipewire.conf" -o /config/pipewire.conf --progress-bar
curl -L "$url/installer/common.sh" -o /installer/common.sh --progress-bar
curl -L "$url/installer/disk.sh" -o /installer/disk.sh --progress-bar
curl -L "$url/installer/install.sh" -o /installer/install.sh --progress-bar
curl -L "$url/installer/programs.sh" -o /installer/programs.sh --progress-bar
curl -L "$url/installer/setup.sh" -o /installer/setup.sh --progress-bar

# run setup
clear
cd /installer
exec bash /installer/setup.sh
