#!/bin/bash
set -e

source /etc/container_environment.sh

if [[ -z "$PGDATA" ]]; then
	echo 'PGDATA is undefined'
	exit 1
fi

if  [[ -n "${PG_BACKUP-}" ]]; then

	if [[ ! -d "$PG_BACKUP" ]]; then
		mkdir -p "$PG_BACKUP"
		chown -R postgres:postgres "$PG_BACKUP"
		chmod -R 0700 "$PG_BACKUP"
	fi

	export WALG_FILE_PREFIX="$PG_BACKUP"
fi

wal-g backup-fetch "$PGDATA" LATEST
