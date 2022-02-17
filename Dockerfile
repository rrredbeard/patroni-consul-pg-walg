ARG REGISTRY='docker.io'
ARG PHUSION_TAG='focal-1.1.0'

FROM $REGISTRY/phusion/baseimage:$PHUSION_TAG

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
    && apt-get upgrade -y

RUN set -o xtrace \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update

RUN set -o xtrace \
    && apt-get install -y postgresql-common \
    && sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf \
    && apt-get install -y \
        postgresql-$PG_MAJOR \
        postgresql-contrib-$PG_MAJOR

RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

RUN set -o xtrace \
    && apt-get install --no-install-recommends -y libpq-dev postgresql-client-$PG_MAJOR \
    && apt-get update \
    && apt-get install -y postgresql-server-dev-$PG_MAJOR

RUN pip install \
    psutil patroni[consul] python-consul dnspython boto mock requests \
    six kazoo click tzlocal prettytable psycopg PyYAML

# wal-g staff
RUN set -o xtrace \
    && wget "https://github.com/wal-g/wal-g/releases/download/$WALG_RELEASE/wal-g.linux-amd64.tar.gz" \
    && tar -zxvf wal-g.linux-amd64.tar.gz \
    && mv wal-g /usr/bin \
    && chmod +x /usr/bin/wal-g \
    && rm wal-g.linux-amd64.tar.gz

# wal-g operational staff
ENV WALG_S3_STORAGE_CLASS STANDARD_IA
ENV WALG_COMPRESSION_METHOD lzma
ENV WALG_UPLOAD_DISK_CONCURRENCY 5

ADD archive_command.sh /usr/bin/archive_command.sh
ADD perform_backup.sh /usr/bin/perform_backup.sh
ADD restore_command.sh /usr/bin/restore_command.sh
ADD restore_backup.sh /usr/bin/restore_backup.sh

RUN chmod 777 /usr/bin/restore_command.sh \
    && chmod 777 /usr/bin/restore_backup.sh  \
    && chmod 755 /usr/bin/archive_command.sh \
    && chmod 755 /usr/bin/perform_backup.sh

# patroni staff
RUN mkdir /etc/service/patroni
ADD run-patroni.sh /etc/service/patroni/run
RUN chmod 755 /etc/service/patroni/run

RUN export TERM=xterm

ENV PATH /usr/bin:$PATH
ENV PATH /usr/lib/postgresql/$PG_MAJOR/bin:$PATH
ENV PGDATA /var/lib/postgresql/data
