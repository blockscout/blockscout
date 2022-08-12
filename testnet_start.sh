#!/bin/bash
set -o allexport && source ./common-blockscout-testnet.env && set +o allexport
#/usr/bin/mix do ecto.create, ecto.migrate, phx.server
/usr/bin/mix phx.server
