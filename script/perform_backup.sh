#!/bin/bash

if [ "200" = "$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8008)" ]; then
	source /etc/container_environment.sh

	if [[ -z "$PGDATA" ]]; then
		echo 'PGDATA is undefined'
		exit 1
	fi

	PGHOST=/var/run/postgresql gosu postgres wal-g backup-push "$PGDATA" \
		&& gosu postgres wal-g delete retain FULL 7 --confirm 2>&1 | /usr/bin/logger -t wal-g
fi
