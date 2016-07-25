FROM debian:8
MAINTAINER DI GREGORIO Nicolas "nicolas.digregorio@gmail.com"

### Environment variables
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

COPY docker-entrypoint.sh /usr/local/bin/

### Install Applications DEBIAN_FRONTEND=noninteractive  --no-install-recommends
RUN perl -npe 's/main/main\ contrib\ non-free/' -i /etc/apt/sources.list && \
    apt-get update && \
    { \
      echo mariadb-server-10 mysql-server/root_password password 'unused'; \
      echo mariadb-server-10 mysql-server/root_password_again password 'unused'; \
    } | debconf-set-selections && \
    groupadd -g 2004 mysql && \
    useradd mysql -u 2004 -g mysql -r -m -d /var/lib/mysql -s /bin/false && \
    apt-get install -y --no-install-recommends ca-certificates mariadb-server socat && \
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
    ln -s usr/local/bin/docker-entrypoint.sh / && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/*

### Volume
VOLUME ["/var/lib/mysql","/etc/mysql/conf.d/"]


### Expose ports
EXPOSE 3306

### Running User
USER   mysql

### Start mysql
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mysqld"]
