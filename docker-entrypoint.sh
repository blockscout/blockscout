#!/bin/sh
set -e

echo "Starting Blockscout..."

# Check if database exists
if [ -z "$DISABLE_DATABASE_MIGRATIONS" ]; then
    echo "Running database migrations..."
    ./bin/blockscout eval "Elixir.Explorer.ReleaseTasks.create_and_migrate()"
fi

echo "Starting Blockscout server..."
exec ./bin/blockscout start