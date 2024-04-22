#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <schain_name> [table1] [table2] ..."
    exit 1
fi

DEFAULT_TABLES=()

BLACKLIST_TABLES=(
    "market_history"
)
DB_USER="blockscout"
DB_NAME="blockscout"
SCHEMA_NAME="public"
DUMPS_DIR="dumps"
LOGS_DIR="logs"
SCHAIN_NAME="$1"
DB_CONTAINER="${SCHAIN_NAME}_db"
shift

if [ ! -d $DUMPS_DIR ]; then
    mkdir $DUMPS_DIR
fi
cd $DUMPS_DIR

if [ ! -d $SCHAIN_NAME ]; then
    mkdir $SCHAIN_NAME
fi
cd $SCHAIN_NAME
rm -rf $LOGS_DIR && mkdir $LOGS_DIR

if [ $# -eq 0 ]; then
    TABLES=("${DEFAULT_TABLES[@]}")
else
    TABLES=("$@")
fi

if [ ${#TABLES[@]} -eq 0 ]; then
    TABLES=$(docker exec -i $DB_CONTAINER psql \
                -U $DB_USER \
                -d $DB_NAME \
                -t -c "SELECT table_name \
                      FROM information_schema.tables \
                      WHERE table_schema='$SCHEMA_NAME' \
                      AND table_type='BASE TABLE' \
                      AND table_name NOT IN ('${BLACKLIST_TABLES[@]}')")
fi

for TABLE in ${TABLES}; do
    DUMP_FILE="${TABLE}.sql"
    LOG_FILE="$LOGS_DIR/${TABLE}.log"

    if [ -f "$DUMP_FILE" ]; then
        echo "Dump file $DUMP_FILE already exists. Skipping table $TABLE..."
    else
        if [ $(docker exec -i $DB_CONTAINER psql \
                -U $DB_USER \
                -d $DB_NAME \
                -t -c "SELECT COUNT(*) FROM $SCHEMA_NAME.$TABLE") -gt 0 ]; then
            echo "Dumping table $TABLE..."
            docker exec -i $DB_CONTAINER pg_dump \
                -U $DB_USER \
                -d $DB_NAME \
                -t $SCHEMA_NAME.$TABLE \
                --column-inserts \
                --data-only \
                --verbose \
                > $DUMP_FILE 2> $LOG_FILE
        fi
    fi
done

echo "Dump completed."
