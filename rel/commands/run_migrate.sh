#!/bin/bash

# Runs the migration tasks on the database 
# exposed at localhost:5432

DATABASE_URL=postgresql://postgres:1234@localhost:5432/blockscout \
    mix ecto.migrate