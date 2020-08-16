FROM centos:7
LABEL maintainer "DI GREGORIO Nicolas <ndigregorio@ndg-consulting.tech>"

### Environment variables
ENV LANG='en_US.UTF-8' \
    LANGUAGE='en_US.UTF-8' \
    TERM='xterm' \
    APPUSER='mysql' \
    APPGID='2004' \
    APPUID='2004' \
    MDB_VERSION='10.5'

# Copy config files
COPY root/ /

### Install Application
RUN set -x && \
    chmod 1777 /tmp && \
    . /usr/local/bin/docker-entrypoint-functions.sh && \
    MYUSER="${APPUSER}" && \
    MYUID="${APPUID}" && \
    MYGID="${APPGID}" && \
    ConfigureUser && \
    yum-config-manager --add-repo /tmp/custom.repo && \
    sed -e "s/MDB_VERSION/${MDB_VERSION}/" -i /tmp/MariaDB.repo && \
    yum-config-manager --add-repo /tmp/MariaDB.repo && \
    yum update -y && \
    yum install -y \
      MariaDB-server \
      MariaDB-backup \
      MariaDB-client \
      socat \
      pwgen \
      su-exec \
      tzdata \
      xz-utils \
    && \
    mkdir /docker-entrypoint-initdb.d && \
    rm -rf /var/lib/mysql && \
    mkdir -p /var/lib/mysql /var/run/mysqld && \
    chown -R "${MYUSER}":"${MYUSER}" /var/lib/mysql /var/run/mysqld && \
    chmod 777 /var/run/mysqld && \
    find /etc/my.cnf.d/ -name '*.cnf' -print0 \
      | xargs -0 grep -lZE '^(bind-address|log|user\s)' \
      | xargs -rt -0 sed -Ei 's/^(bind-address|log|user\s)/#&/' \
    && \
    yum clean all && \
    mkdir /docker-entrypoint.d && \
    chmod +x /usr/local/bin/docker-entrypoint.sh && \
    ln -snf /usr/local/bin/docker-entrypoint.sh /docker-entrypoint.sh && \
    rm -rf /tmp/* \
           /var/cache/yum/* \
           /var/tmp/*
    
# Expose volumes
VOLUME ["/var/lib/mysql"]

# Expose ports
EXPOSE 3386

### Running User: not used, managed by docker-entrypoint.sh
USER root

### Start mariadb
COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["mysqld"]

