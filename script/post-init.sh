#!/usr/bin/env bash

set -e

echo
echo "Running post-init scripts"
echo "$@"
echo

for file in /post-init/*; do
	# shellcheck disable=SC1090
	case "$file" in
	*.sh)
		echo "$0: running $file"
		. "$file" "$@"
		;;
	*) echo "$0: ignoring $file" ;;
	esac
	echo
done

echo
echo "Done running post-init scripts"
echo
