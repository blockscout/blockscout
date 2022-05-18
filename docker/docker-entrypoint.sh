#!/bin/sh

set -e

mix do ecto.create, ecto.migrate, phx.server
