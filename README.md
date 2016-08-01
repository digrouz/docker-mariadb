# docker-deb-mariadb
Install Mariadb into Debian Jessie Container

![mariadb](https://mariadb.org/wp-content/uploads/2015/05/MariaDB-Foundation-horizontal-x52.png)

# Description

MariaDB is a community-developed fork of the MySQL relational database management system intended to remain free under the GNU GPL. It is notable for being led by the original developers of MySQL, who forked it due to concerns over its acquisition by Oracle.[4] Contributors are required to share their copyright with the MariaDB Foundation

# Usage
    docker create --name=mariadb \
     -v <path to data>:/var/lib/mysql \
     -v <path to config>:/etc/mysql/conf.d \
     -v /etc/localtime:/etc/localtime:ro \
     -p 3306:3306 \
     -e MYSQL_ROOT_PASSWORD="<password>"  digrouz/docker-deb-mariadb
