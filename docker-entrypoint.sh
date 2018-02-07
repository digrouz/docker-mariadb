#!/usr/bin/env bash
#set -eo pipefail
#shopt -s nullglob

MYUSER="mysql"
MYGID="2004"
MYUID="2004"
OS=""
MYUPGRADE="0"

DectectOS(){
  if [ -e /etc/alpine-release ]; then
    OS="alpine"
  elif [ -e /etc/os-release ]; then
    if grep -q "NAME=\"Ubuntu\"" /etc/os-release ; then
      OS="ubuntu"
    fi
    if grep -q "NAME=\"CentOS Linux\"" /etc/os-release ; then
      OS="centos"
    fi
  fi
}

AutoUpgrade(){
  if [ "$(id -u)" = '0' ]; then
    if [ -n "${DOCKUPGRADE}" ]; then
      MYUPGRADE="${DOCKUPGRADE}"
    fi
    if [ "${MYUPGRADE}" == 1 ]; then
      if [ "${OS}" == "alpine" ]; then
        apk --no-cache upgrade
        rm -rf /var/cache/apk/*
      elif [ "${OS}" == "ubuntu" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get -y --no-install-recommends dist-upgrade
        apt-get -y autoclean
        apt-get -y clean
        apt-get -y autoremove
        rm -rf /var/lib/apt/lists/*
      elif [ "${OS}" == "centos" ]; then
        yum upgrade -y
        yum clean all
        rm -rf /var/cache/yum/*
      fi
    fi
  fi
}

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"
  if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
    echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
    exit 1
  fi
  local val="$def"
  if [ "${!var:-}" ]; then
    val="${!var}"
  elif [ "${!fileVar:-}" ]; then
    val="$(< "${!fileVar}")"
  fi
  export "$var"="$val"
  unset "$fileVar"
}

ConfigureUser () {
  if [ "$(id -u)" = '0' ]; then
    # Managing user
    if [ -n "${DOCKUID}" ]; then
      MYUID="${DOCKUID}"
    fi
    # Managing group
    if [ -n "${DOCKGID}" ]; then
      MYGID="${DOCKGID}"
    fi
    local OLDHOME
    local OLDGID
    local OLDUID
    if grep -q "${MYUSER}" /etc/passwd; then
      OLDUID=$(id -u "${MYUSER}")
    fi
    if grep -q "${MYUSER}" /etc/group; then
      OLDGID=$(id -g "${MYUSER}")
    fi
    if [ -n "${OLDUID}" ] && [ "${MYUID}" != "${OLDUID}" ]; then
      OLDHOME=$(grep "$MYUSER" /etc/passwd | awk -F: '{print $6}')
      if [ "${OS}" == "alpine" ]; then
        deluser "${MYUSER}"
      else
        userdel "${MYUSER}"
      fi
      DockLog "Deleted user ${MYUSER}"
    fi
    if grep -q "${MYUSER}" /etc/group; then
      if [ "${MYGID}" != "${OLDGID}" ]; then
        if [ "${OS}" == "alpine" ]; then
          delgroup "${MYUSER}"
        else
          groupdel "${MYUSER}"
        fi
        DockLog "Deleted group ${MYUSER}"
      fi
    fi
    if ! grep -q "${MYUSER}" /etc/group; then
      if [ "${OS}" == "alpine" ]; then
        addgroup -S -g "${MYGID}" "${MYUSER}"
      else
        groupadd -r -g "${MYGID}" "${MYUSER}"
      fi
      DockLog "Created group ${MYUSER}"
    fi
    if ! grep -q "${MYUSER}" /etc/passwd; then
      if [ -z "${OLDHOME}" ]; then
        OLDHOME="/home/${MYUSER}"
        mkdir "${OLDHOME}"
        DockLog "Created home directory ${OLDHOME}"
      fi
      if [ "${OS}" == "alpine" ]; then
        adduser -S -D -H -s /sbin/nologin -G "${MYUSER}" -h "${OLDHOME}" -u "${MYUID}" "${MYUSER}"
      else
        useradd --system --shell /sbin/nologin --gid "${MYGID}" --home-dir "${OLDHOME}" --uid "${MYUID}" "${MYUSER}"
      fi
      DockLog "Created user ${MYUSER}"

    fi
    if [ -n "${OLDUID}" ] && [ "${MYUID}" != "${OLDUID}" ]; then
      DockLog "Fixing permissions for user ${MYUSER}"
      find / -user "${OLDUID}" -exec chown ${MYUSER} {} \; &> /dev/null
      if [ "${OLDHOME}" == "/home/${MYUSER}" ]; then
        chown -R "${MYUSER}" "${OLDHOME}"
        chmod -R u+rwx "${OLDHOME}"
      fi
      DockLog "... done!"
    fi
    if [ -n "${OLDGID}" ] && [ "${MYGID}" != "${OLDGID}" ]; then
      DockLog "Fixing permissions for group ${MYUSER}"
      find / -group "${OLDGID}" -exec chgrp ${MYUSER} {} \; &> /dev/null
      if [ "${OLDHOME}" == "/home/${MYUSER}" ]; then
        chown -R :"${MYUSER}" "${OLDHOME}"
        chmod -R ga-rwx "${OLDHOME}"
      fi
      DockLog "... done!"
    fi
  fi
}

DockLog(){
  if [ "${OS}" == "centos" ] || [ "${OS}" == "alpine" ]; then
    echo "${1}"
  else
    logger "${1}"
  fi
}

DectectOS
AutoUpgrade
ConfigureUser

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

# skip setup if they want an option that stops mysqld
wantHelp=
for arg; do
	case "$arg" in
		-'?'|--help|--print-defaults|-V|--version)
			wantHelp=1
			break
			;;
	esac
done

_check_config() {
	toRun=( "$@" --verbose --help --log-bin-index="$(mktemp -u)" )
	if ! errors="$("${toRun[@]}" 2>&1 >/dev/null)"; then
		cat >&2 <<-EOM
			ERROR: mysqld failed while attempting to check config
			command was: "${toRun[*]}"
			$errors
		EOM
		exit 1
	fi
}

# Fetch value from server config
# We use mysqld --verbose --help instead of my_print_defaults because the
# latter only show values present in config files, and not server defaults
_get_config() {
	local conf="$1"; shift
	"$@" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null | awk '$1 == "'"$conf"'" { print $2; exit }'
}

# allow the container to be started with `--user`
if [ "$1" = 'mysqld' -a -z "$wantHelp" -a "$(id -u)" = '0' ]; then
	_check_config "$@"
	DATADIR="$(_get_config 'datadir' "$@")"
	mkdir -p "$DATADIR"
	chown -R mysql:mysql "$DATADIR"
	exec su-exec mysql "$BASH_SOURCE" "$@"
fi

if [ "$1" = 'mysqld' -a -z "$wantHelp" ]; then
	# still need to check config, container may have started with --user
	_check_config "$@"
	# Get config
	DATADIR="$(_get_config 'datadir' "$@")"

	if [ ! -d "$DATADIR/mysql" ]; then
		file_env 'MYSQL_ROOT_PASSWORD'
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			DockLog 'error: database is uninitialized and password option is not specified '
			DockLog '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
			exit 1
		fi

		mkdir -p "$DATADIR"

		DockLog 'Initializing database'
		mysql_install_db --datadir="$DATADIR" --rpm
		DockLog 'Database initialized'

		SOCKET="$(_get_config 'socket' "$@")"
		"$@" --skip-networking --socket="${SOCKET}" &
		pid="$!"

		mysql=( mysql --protocol=socket -uroot -hlocalhost --socket="${SOCKET}" )

		for i in {30..0}; do
			if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
				break
			fi
			DockLog 'MySQL init process in progress...'
			sleep 1
		done
		if [ "$i" = 0 ]; then
			DockLog 'MySQL init process failed.'
			exit 1
		fi

		if [ -z "$MYSQL_INITDB_SKIP_TZINFO" ]; then
			# sed is for https://bugs.mysql.com/bug.php?id=20545
			mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/' | "${mysql[@]}" mysql
		fi

		if [ ! -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			export MYSQL_ROOT_PASSWORD="$(pwgen -1 32)"
			DockLog "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
		fi

		rootCreate=
		# default root to listen for connections from anywhere
		file_env 'MYSQL_ROOT_HOST' '%'
		if [ ! -z "$MYSQL_ROOT_HOST" -a "$MYSQL_ROOT_HOST" != 'localhost' ]; then
			# no, we don't care if read finds a terminating character in this heredoc
			# https://unix.stackexchange.com/questions/265149/why-is-set-o-errexit-breaking-this-read-heredoc-expression/265151#265151
			read -r -d '' rootCreate <<-EOSQL || true
				CREATE USER 'root'@'${MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
				GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION ;
			EOSQL
		fi

		"${mysql[@]}" <<-EOSQL
			-- What's done in this file shouldn't be replicated
			--  or products like mysql-fabric won't work
			SET @@SESSION.SQL_LOG_BIN=0;
			DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost') ;
			SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}') ;
			GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION ;
			${rootCreate}
			DROP DATABASE IF EXISTS test ;
			FLUSH PRIVILEGES ;
		EOSQL

		if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
			mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
		fi

		file_env 'MYSQL_DATABASE'
		if [ "$MYSQL_DATABASE" ]; then
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
			mysql+=( "$MYSQL_DATABASE" )
		fi

		file_env 'MYSQL_USER'
		file_env 'MYSQL_PASSWORD'
		if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
			echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" | "${mysql[@]}"

			if [ "$MYSQL_DATABASE" ]; then
				echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" | "${mysql[@]}"
			fi

			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)     echo "$0: running $f"; . "$f" ;;
				*.sql)    echo "$0: running $f"; "${mysql[@]}" < "$f"; echo ;;
				*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${mysql[@]}"; echo ;;
				*)        echo "$0: ignoring $f" ;;
			esac
			echo
		done

		if ! kill -s TERM "$pid" || ! wait "$pid"; then
			DockLog 'MySQL init process failed.'
			exit 1
		fi

		DockLog 'MySQL init process done. Ready for start up.'
	fi
fi

exec "$@"