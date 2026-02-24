# --- functions ---
as_user() {
	local username=$1
	shift
	sudo -H -u "$username" bash -lc "\"$@\""
}

install() {
	apt install -y "$@" >/dev/null
}

update() {
	apt update -y >/dev/null
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
