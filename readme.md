# Debian
My scripts for installing debian with my configs/dotfiles and programs.

## Usage
Simply run:
```bash
su - root -c "apt install -y curl; curl -L https://github.com/Hasibix/debian/raw/refs/heads/main/debian.sh --progress-bar -o /debian.sh; bash /debian.sh"
```
from a Debian live environment.

The scripts will guide you through the installation process.

NOTE: Since this a set of installer scripts, you **WILL** be asked to **wipe the disk** you want to install Debian into.
