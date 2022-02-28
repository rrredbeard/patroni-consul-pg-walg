ARG PHUSION_REGISTRY='docker.io'
ARG PHUSION_TAG='focal-1.1.0'

FROM --platform=amd64 $PHUSION_REGISTRY/phusion/baseimage:$PHUSION_TAG

MAINTAINER Andy Fefelov <andy@mastery.pro>

ARG PG_MAJOR='11'
ARG WALG_RELEASE='v1.1'

SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get install -y ca-certificates wget sudo gosu htop vim curl git \
        iftop iotop iperf net-tools iputils-ping python3-pip

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - \
    && apt-get update \
    && apt-get upgrade -o Dpkg::Options::="--force-confold" --force-yes -y

RUN set -o xtrace \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update

RUN set -o xtrace \
    && apt-get install -y postgresql-common \
    && sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf \
    && apt-get install -y \
        "postgresql-$PG_MAJOR" \
        "postgresql-contrib-$PG_MAJOR"

RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

RUN set -o xtrace \
    && apt-get install --no-install-recommends -y libpq-dev "postgresql-client-$PG_MAJOR" \
    && apt-get update \
    && apt-get install -y "postgresql-server-dev-$PG_MAJOR"

RUN pip install \
    psutil patroni[consul] python-consul dnspython boto mock requests \
    six kazoo click tzlocal prettytable psycopg PyYAML

# wal-g staff
RUN set -o xtrace \
    && wget "https://github.com/wal-g/wal-g/releases/download/$WALG_RELEASE/wal-g-pg-ubuntu-$(lsb_release -rs)-amd64.tar.gz" \
    && tar -zxvf "wal-g-pg-ubuntu-$(lsb_release -rs)-amd64.tar.gz" \
    && mv "wal-g-pg-ubuntu-$(lsb_release -rs)-amd64" /usr/bin/wal-g \
    && chmod +x /usr/bin/wal-g \
    && rm "wal-g-pg-ubuntu-$(lsb_release -rs)-amd64.tar.gz"

# wal-g operational staff
ENV WALG_S3_STORAGE_CLASS STANDARD_IA
ENV WALG_COMPRESSION_METHOD lzma
ENV WALG_UPLOAD_DISK_CONCURRENCY 5

ADD script/archive_command.sh /usr/bin/archive_command.sh
ADD script/perform_backup.sh /usr/bin/perform_backup.sh
ADD script/restore_command.sh /usr/bin/restore_command.sh
ADD script/restore_backup.sh /usr/bin/restore_backup.sh
ADD script/post-init.sh /usr/bin/patroni-post-init.sh
ADD config/00_patroni.yml /var/lib/postgresql/patroni.yml

RUN mkdir /post-init \
    && chmod 755 /post-init \
    && chmod 777 /usr/bin/restore_command.sh \
    && chmod 777 /usr/bin/restore_backup.sh  \
    && chmod 755 /usr/bin/archive_command.sh \
    && chmod 755 /usr/bin/perform_backup.sh \
    && chmod 755 /usr/bin/patroni-post-init.sh \
    && chmod 755 /var/lib/postgresql/patroni.yml

# patroni staff
RUN mkdir -p "/etc/service/patroni"
ADD script/run-patroni.sh /etc/service/patroni/run

RUN chmod 755 /etc/service/patroni/run

RUN export TERM=xterm

ENV PATH "/usr/bin:$PATH"
ENV PATH "/usr/lib/postgresql/$PG_MAJOR/bin:$PATH"
ENV PGDATA "/var/lib/postgresql/data/PGDATA"

RUN set -o xtrace \
    && mkdir -p "/var/lib/postgresql/data" \
    && chown -R postgres:postgres "/var/lib/postgresql/data" \
    && chmod -R 700 "/var/lib/postgresql/data"

VOLUME ["/var/lib/postgresql/data"]

EXPOSE 8008 5432

HEALTHCHECK --interval=10s --timeout=30s --start-period=30s \
  CMD curl -fs http://localhost:8008/health || exit 1


#### moved here to optimize layer caching

ARG APP_VERSION='v0.0.0'

# after FROM args are empty
ARG PHUSION_REGISTRY='docker.io'
ARG PHUSION_TAG='focal-1.1.0'

LABEL org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.title='Ubuntu fat image with Patroni, Postgres and WAL-G' \
      org.opencontainers.image.source='https://github.com/rrredbeard/patroni-consul-pg-walg' \
      org.opencontainers.image.base.name="${PHUSION_REGISTRY}/phusion/baseimage:${PHUSION_TAG}" \
      org.opencontainers.image.description="Image based on 'phusion/baseimage' containing Postgres ${PG_MAJOR}, WAL-G ${WALG_RELEASE} and Patroni that supports only Consul as key/value store"
