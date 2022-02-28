#!/bin/bash
set -e
source /etc/container_environment.sh

if [[ -z "$PGDATA" ]]; then
	echo 'PGDATA is undefined'
	exit 1
fi

if [ -n "$WALE_S3_PREFIX" ]; then
	wal-g wal-push "$PGDATA/$1" > /dev/null 2>&1
fi
