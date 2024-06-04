#!/usr/bin/env bash

#
# Dumps database to /dev/shm/$ENV_NAME/db-dump-DATE.sql.gz in deployment container
#

set -e

# extract database host and port from Helm values
export PGHOST=$(yq -r '.databaseHost' ${ENV_BASE_DIR}/values.yaml)
export PGPORT=$(yq -r '.databasePort' ${ENV_BASE_DIR}/values.yaml)
export PGDATABASE=$(yq -r '.databaseName' ${ENV_BASE_DIR}/values.yaml)
export PGUSER=$(yq -r '.databaseUser' ${ENV_BASE_DIR}/values.yaml)

# Explicitly require SSL to avoid connecting over plain TCP
export PGSSLMODE=require

# defaults for databases with default user and database name
[[ $PGDATABASE == 'null' ]] && export PGDATABASE=pebbles
[[ $PGUSER == 'null' ]] && export PGUSER=pebbles

# extract db password from database secret file
if [[ ! -e ${ENV_BASE_DIR}/secrets-database.sops.yaml ]]; then
    echo "ERROR: database password needs to be stored in secrets-database.sops.yaml"
    return 1
fi
db_password=$(sops -d --extract '["databasePassword"]' ${ENV_BASE_DIR}/secrets-database.sops.yaml)

# create a password file
export PGPASSFILE=/dev/shm/$ENV_NAME/.pgpass
touch $PGPASSFILE && chmod 600 $PGPASSFILE
# hostname:port:database:username:password
echo "$PGHOST:$PGPORT:$PGDATABASE:$PGUSER:$db_password" > $PGPASSFILE
unset db_password

# finally dump database
dump_file=/dev/shm/$ENV_NAME/db-dump-$(date -Is).sql.gz
echo "dumping database $PGHOST:$PGPORT/$PGDATABASE to $dump_file"
pg_dump --clean | gzip > $dump_file
ls -lash $dump_file
echo "done"

# clean up
rm $PGPASSFILE
unset PGHOST PGPORT PGDATABASE PGUSER PGPASSFILE PGSSLMODE
