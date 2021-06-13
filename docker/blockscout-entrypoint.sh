#!/bin/bash
#
# Blockscout entrypoint
#
########################################################


# Waiting for database to come-up
sleep 10

# Perform database migration
mix do ecto.create, ecto.migrate

# Start server
exec mix phx.server