#!/bin/bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if [ "$(id -u)" -ne 0 ]; then
	echo "this script must be run as root"
	exit 1
fi

# --- functions ---
as_user() {
	local username=$1
	shift
	sudo -H -u "$username" bash -lc "\"$@\""
}

install() {
	apt install -y "$@" >/dev/null 2>&1
}

update() {
	apt update -y >/dev/null 2>&1
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
