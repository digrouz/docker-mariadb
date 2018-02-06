# docker-mariadb
Install Mariadb into a Linux Container

![mariadb](https://mariadb.org/wp-content/uploads/2015/05/MariaDB-Foundation-horizontal-x52.png)

## Tags
Several tags are available:
* `latest`: see `10.2-centos7`
* `10.2-centos7`: [10.2-centos7/Dokerfile](https://github.com/digrouz/docker-mariadb/blob/10.2-centos7/Dockerfile)

## Description

MariaDB is a community-developed fork of the MySQL relational database management system intended to remain free under the GNU GPL. It is notable for being led by the original developers of MySQL, who forked it due to concerns over its acquisition by Oracle.[4] Contributors are required to share their copyright with the MariaDB Foundation

https://mariadb.org

## Usage
    docker create --name=mariadb \
      -v <path to data>:/var/lib/mysql \
      -v /etc/localtime:/etc/localtime:ro \
      -p 3306:3306 \
      -e DOCKUID=<UID default:2004> \
      -e DOCKGID=<GID default:2004> \
      -e DOCKUPGRADE=<0|1> \
      -e MYSQL_ROOT_PASSWORD="<password>"  \
    digrouz/mariadb

## Environment Variables

When you start the `mariadb` image, you can adjust the configuration of the MariaDB instance by passing one or more environment variables on the `docker run` command line. Do note that none of the variables below will have any effect if you start the container with a data directory that already contains a database: any pre-existing database will always be left untouched on container startup.

### `DOCKUID`

This variable is not mandatory and specifies the user id that will be set to run the application. It has default value `2004`.

### `DOCKGID`

This variable is not mandatory and specifies the group id that will be set to run the application. It has default value `2004`.

### `DOCKUPGRADE`

This variable is not mandatory and specifies if the container has to launch software update at startup or not. Valid values are `0` and `1`. It has default value `0`.

### `MYSQL_ROOT_PASSWORD`

This variable is mandatory and specifies the password that will be set for the MariaDB `root` superuser account. In the above example, it was set to `my-secret-pw`.

### `MYSQL_DATABASE`

This variable is optional and allows you to specify the name of a database to be created on image startup. If a user/password was supplied (see below) then that user will be granted superuser access ([corresponding to `GRANT ALL`](http://dev.mysql.com/doc/en/adding-users.html)) to this database.

### `MYSQL_USER`, `MYSQL_PASSWORD`

These variables are optional, used in conjunction to create a new user and to set that user's password. This user will be granted superuser permissions (see above) for the database specified by the `MYSQL_DATABASE` variable. Both variables are required for a user to be created.

Do note that there is no need to use this mechanism to create the root superuser, that user gets created by default with the password specified by the `MYSQL_ROOT_PASSWORD` variable.

### `MYSQL_ALLOW_EMPTY_PASSWORD`

This is an optional variable. Set to `yes` to allow the container to be started with a blank password for the root user. *NOTE*: Setting this variable to `yes` is not recommended unless you really know what you are doing, since this will leave your MariaDB instance completely unprotected, allowing anyone to gain complete superuser access.

### `MYSQL_RANDOM_ROOT_PASSWORD`

This is an optional variable. Set to `yes` to generate a random initial password for the root user (using `pwgen`). The generated root password will be printed to stdout (`GENERATED ROOT PASSWORD: .....`).

### `MYSQL_ONETIME_PASSWORD`

Sets root (*not* the user specified in `MYSQL_USER`!) user as expired once init is complete, forcing a password change on first login. *NOTE*: This feature is supported on MySQL 5.6+ only. Using this option on MySQL 5.5 will throw an appropriate error during initialization.

## Notes

* The docker entrypoint can upgrade operating system at each startup. To enable this feature, just add `-e DOCKUPGRADE=1` at container creation.
* As an alternative to passing sensitive information via environment variables, `_FILE` may be appended to the previously listed environment variables, causing the initialization script to load the values for those variables from files present in the container. In particular, this can be used to load passwords from Docker secrets stored in `/run/secrets/<secret_name>` files. 
* When a container is started for the first time, a new database with the specified name will be created and initialized with the provided configuration variables. Furthermore, it will execute files with extensions `.sh`, `.sql` and `.sql.gz` that are found in `/docker-entrypoint-initdb.d`.
* Note that users on host systems with `SELinux` enabled may see issues when storing data files outside the container. The current workaround is to assign the relevant `SELinux` policy type to the new data directory so that the container will be allowed to access it:

    $ chcon -Rt svirt_sandbox_file_t /my/own/datadir

## Issues

If you encounter an issue please open a ticket at [github](https://github.com/digrouz/docker-mariadb/issues)