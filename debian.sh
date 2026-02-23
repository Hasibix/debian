#!/bin/bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
	echo "this script must be run as root"
	exit 1
fi

# --- main ---
url="https://github.com/Hasibix/debian/raw/refs/heads/main"

if ! command -v curl &> /dev/null; then
    echo "curl not found, installing..."
    apt update -y
    apt install -y curl
fi

mkdir -p /installer
mkdir -p /config
curl -L "$url/config/pipewire.conf" -o /config/pipewire.conf --progress-bar
curl -L "$url/installer/disk.sh" -o /installer/disk.sh --progress-bar
curl -L "$url/installer/install.sh" -o /installer/install.sh --progress-bar
curl -L "$url/installer/setup.sh" -o /installer/setup.sh --progress-bar

# run setup
cd /installer
exec bash /installer/setup.sh
