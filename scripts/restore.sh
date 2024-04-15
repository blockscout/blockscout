#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <schain_name> [table1 table2 ...]"
    exit 1
fi

SCHAIN_NAME="$1"
shift
TABLES=("$@") 
DEFAULT_TABLES=()
DUMPS_DIR="dumps/$SCHAIN_NAME"
LOGS_DIR="restore/$SCHAIN_NAME/logs"
ERROR_LOGS_DIR="restore/$SCHAIN_NAME/error_logs"


if [ ! -d $DUMPS_DIR ]; then
    echo "Error: Dump directory for schain $SCHAIN_NAME not found."
    exit 1
fi

rm -rf "$LOGS_DIR" && mkdir -p "$LOGS_DIR"
rm -rf "$ERROR_LOGS_DIR" && mkdir -p "$ERROR_LOGS_DIR"

if [ "${#TABLES[@]}" -eq 0 ]; then
    TABLES=("${DEFAULT_TABLES[@]}")
fi

if [ "${#TABLES[@]}" -eq 0 ]; then
    readarray -t TABLES < <(find "$DUMPS_DIR" -type f -name "*.sql" -exec basename {} \; | sed 's/\.sql$//')
fi

for TABLE_NAME in "${TABLES[@]}"; do
    DUMP_FILE="$DUMPS_DIR/${TABLE_NAME}.sql"
    if [ -f "$DUMP_FILE" ]; then
        LOG_FILE="${LOGS_DIR}/${TABLE_NAME}.log"
        ERRORS_LOG_FILE="${ERROR_LOGS_DIR}/${TABLE_NAME}.log"
        
        echo "Restoring from $DUMP_FILE..."
        docker exec -i "${SCHAIN_NAME}_db" psql -U blockscout -d blockscout < "$DUMP_FILE" > "$LOG_FILE" 2> "$ERRORS_LOG_FILE"
    fi
done

echo "Restoration process completed."
