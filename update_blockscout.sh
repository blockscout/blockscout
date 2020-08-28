#!/bin/bash

set -x

sudo systemctl stop explorer.service
git pull origin production-rsk-stg
MIX_ENV=prod mix do deps.get, deps.compile, compile
MIX_ENV=prod mix do ecto.migrate
cd apps/block_scout_web/assets; sudo npm install && node_modules/webpack/bin/webpack.js --mode production; cd -
cd apps/explorer && npm install; cd -
MIX_ENV=prod mix phx.digest
sudo systemctl start explorer.service