#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    ALTER SCHEMA public OWNER TO blockscout;
    GRANT ALL ON SCHEMA public TO blockscout;
    GRANT CREATE ON SCHEMA public TO blockscout;
    GRANT ALL PRIVILEGES ON DATABASE blockscout TO blockscout;
EOSQL