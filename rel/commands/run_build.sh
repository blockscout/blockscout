#!/bin/bash

# Deletes existing build artifacts and dependencies, including node_modules
# and rebuilds the entire application from scratch
# Comment out various parts as you require 
# (For example the node_modules may not need to be rebuilt every time)

rm ./_build -rf
rm ./deps -rf
rm ./apps/block_scout_web/assets/node_modules -rf
rm ./apps/explorer/node_modules -rf
rm ./logs/dev -rf

mix local.hex --force
mix local.rebar --force
mix deps.get

cd apps/block_scout_web/assets/ && \
  npm install && \
  npm run build && \
  npm rebuild node-sass && \
  cd -

cd apps/explorer/ && \
  npm install && \
  cd -

mix compile