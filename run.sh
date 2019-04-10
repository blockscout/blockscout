#!/bin/sh
# Adapted from Alex Kleissner's post, Running a Phoenix 1.3 project with docker-compose
# https://medium.com/@hex337/running-a-phoenix-1-3-project-with-docker-compose-d82ab55e43cf
# with some modifications for blockscout

set -e

# Ensure the app's dependencies are installed
mix deps.get

# Prepare Dialyzer if the project has Dialyxer set up
if mix help dialyzer >/dev/null 2>&1
then
  echo "Found Dialyxer: Setting up PLT..."
  mix do deps.compile, dialyzer --plt
else
  echo "No Dialyxer config: Skipping setup..."
fi

echo "Installing JS Dependencies..."
cd apps/block_scout_web/assets/ && \
    npm install && \
    npm run deploy && \
    cd -

cd apps/explorer/ && \
    npm install && \
    cd -

# Wait for Postgres to become available.
until psql -h db -U "postgres" -c '\q' 2>/dev/null; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

echo "Postgres is available: continuing with database setup..."

# Potentially Set up the database
mix ecto.create
mix ecto.migrate

echo " Launching Phoenix web server..."
mix phx.server