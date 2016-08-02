# vim:set ft=dockerfile:
FROM debian:8
MAINTAINER DI GREGORIO Nicolas "nicolas.digregorio@gmail.com"

### Environment variables
ENV GOSU_VERSION 1.9

### Install Applications DEBIAN_FRONTEND=noninteractive  --no-install-recommends
RUN perl -npe 's/main/main\ contrib\ non-free/' -i /etc/apt/sources.list && \
    apt-get update && \
    { \
      echo mariadb-server-10 mysql-server/root_password password 'unused'; \
      echo mariadb-server-10 mysql-server/root_password_again password 'unused'; \
    } | debconf-set-selections && \
    groupadd -g 2004 mysql && \
    useradd mysql -u 2004 -g mysql -r -m -d /var/lib/mysql -s /bin/false && \
    apt-get install -y --no-install-recommends ca-certificates mariadb-server socat wget && \
    wget --no-check-certificate https://raw.githubusercontent.com/digrouz/docker-deb-mariadb/master/docker-entrypoint.sh -O /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh && \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)"  && \
    wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
    rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc && \
    chmod +x /usr/local/bin/gosu && \
    sed -ri 's/^user\s/#&/' /etc/mysql/my.cnf /etc/mysql/conf.d/* && \
    rm -rf /var/lib/mysql && \
    mkdir -p /var/lib/mysql /var/run/mysqld && \ 
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld && \
    chmod 777 /var/run/mysqld && \
    sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/my.cnf && \
    echo 'skip-host-cache\nskip-name-resolve' | awk '{ print } $1 == "[mysqld]" && c == 0 { c = 1; system("cat") }' /etc/mysql/my.cnf > /tmp/my.cnf  && \
    mv /tmp/my.cnf /etc/mysql/my.cnf && \
    apt-get -y autoclean && \ 
    apt-get -y clean && \
    apt-get -y autoremove && \
    ln -s /usr/local/bin/docker-entrypoint.sh / && \
    gosu nobody true && \
    apt-get purge -y --auto-remove ca-certificates wget && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/tmp/*

### Volume
VOLUME ["/var/lib/mysql","/etc/mysql/conf.d/"]

### Expose ports
EXPOSE 3306

### Running User
USER   mysql

### Start mysql
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["mysqld"]
