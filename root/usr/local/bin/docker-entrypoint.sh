#!/usr/bin/env bash
#set -eo pipefail
#shopt -s nullglob

. /etc/profile
. /usr/local/bin/docker-entrypoint-functions.sh
. /usr/local/bin/mariadb-entrypoint-functions.sh

MYUSER="${APPUSER}"
MYUID="${APPUID}"
MYGID="${APPGID}"

ConfigureUser

if [ "${1}" == 'mariadb' ]; then

else
  DockLog "Running command: ${1}"
  exec "$@"
fi
