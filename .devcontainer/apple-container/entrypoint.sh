#!/usr/bin/env bash
# Prepares the database volume, starts PostgreSQL, then runs the container command.
set -euo pipefail

PG_BIN="/usr/lib/postgresql/${PG_MAJOR}/bin"

# PGDATA is a subdirectory of the volume, because the volume root holds
# lost+found and initdb refuses a non-empty directory.
mkdir -p "$PGDATA" /var/run/postgresql
chown postgres:postgres "$(dirname "$PGDATA")" "$PGDATA" /var/run/postgresql
chmod 700 "$PGDATA"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "postgres" > /tmp/pgpass
  chown postgres /tmp/pgpass
  su postgres -c "$PG_BIN/initdb -D $PGDATA -U postgres --pwfile=/tmp/pgpass --auth-local=trust --auth-host=scram-sha-256"
  rm -f /tmp/pgpass
fi

su postgres -c "$PG_BIN/pg_ctl -D $PGDATA -w -l $PGDATA/server.log \
  -o \"-c listen_addresses=localhost -c max_connections=250\" start"

su postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='app'\" | grep -q 1 || createdb app"

stop_postgres() {
  su postgres -c "$PG_BIN/pg_ctl -D $PGDATA -m fast stop" || true
  exit 0
}
trap stop_postgres TERM INT

"$@" &
wait $!
