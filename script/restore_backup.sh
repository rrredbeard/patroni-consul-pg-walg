#!/bin/bash
set -e

source /etc/container_environment.sh

if [[ -z "$PGDATA" ]]; then
	echo 'PGDATA is undefined'
	exit 1
fi

wal-g backup-fetch "$PGDATA" LATEST
