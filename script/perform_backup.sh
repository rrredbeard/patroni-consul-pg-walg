#!/bin/bash

if [ "200" = "$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8008)" ]; then
	source /etc/container_environment.sh

	if [[ -z "$PGDATA" ]]; then
		echo 'PGDATA is undefined'
		exit 1
	fi

	if [[ -n "${PG_BACKUP-}" ]]; then

		if [[ ! -d "$PG_BACKUP" ]]; then
			mkdir -p "$PG_BACKUP"
			chown -R postgres:postgres "$PG_BACKUP"
			chmod -R 0700 "$PG_BACKUP"
		fi

		export WALG_FILE_PREFIX="$PG_BACKUP"
	fi

	PGHOST=/var/run/postgresql gosu postgres wal-g backup-push "$PGDATA" \
		&& gosu postgres wal-g delete retain FULL 7 --confirm 2>&1 | /usr/bin/logger -t wal-g
fi
