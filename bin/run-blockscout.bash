#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=en_US.UTF-8


COMMAND=${1:-"help"}

__PWD=$PWD
__DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
__PARENT_DIR=$(dirname $__DIR)

echo -e "\n\n $(<$__DIR/banner.txt) \n\n"

if [[ -f $__DIR/config.rc ]]; then

    #echo -e "Loading config from $__DIR/config.rc"
    set -o allexport
    source $__DIR/config.rc
    set +o allexport
fi

#### Main

if [[ $COMMAND == "help" ]]; then

    echo -e "Script for running & compiling blockscout. This script supports:"
    echo -e "\t - Compiling Blockscout"
    echo -e "\t - Dropping and migrating the database"
    echo -e "\t - Run Blockscout"
    echo -e "\t - Run only the fetcher"
    echo -e "\t - Run only the web"

    echo -e "Options:"
    echo -e "$0 <COMMAND>"
    echo -e "\t - Command; comma separated list of actions to execute. Options are: help, compile, compile-full, migrate, start, start-fetcher, start-web"
    echo -e "\n"
    exit 0
fi


if [[ $COMMAND == "compile-full" ]]; then

    echo -e ">> Installing dependencies ..."
    mix do deps.get, local.rebar --force, deps.compile, compile

    echo -e ">> Installing Node dependencies ..."
    cd apps/block_scout_web/assets; npm install && node_modules/webpack/bin/webpack.js --mode production; cd -
    cd apps/explorer && npm install; cd -

    COMMAND="compile"
fi

if [[ $COMMAND == "compile" ]]; then

    echo -e ">> Compiling Blockscout ..."
#    rm -rf apps/block_scout_web/priv/static

    mix phx.digest
    mix compile

    echo -e ">> Enabling HTTPS ..."
    cd apps/block_scout_web
    mix phx.gen.cert blockscout blockscout.local; cd -
fi


if [[ $COMMAND == "migrate" ]]; then

  echo -e ">> Creating and migrating database ..."
  mix do ecto.drop, ecto.create, ecto.migrate
fi


if [[ $COMMAND == "migrate" ]]; then

  echo -e ">> Creating and migrating database ..."
  mix do ecto.drop, ecto.create, ecto.migrate
fi


if [[ $COMMAND == "start" ]]; then

  echo -e ">> Running full Blockscout ..."
  #screen -S blockscout-indexer -d -m mix phx.server
  #screen -ls
  mix phx.server
fi


if [[ $COMMAND == "start-fetcher" ]]; then

  echo -e ">> Running Fetcher ..."
#  screen -S blockscout-web -d -m mix cmd --app indexer iex -S mix
#  screen -ls
  mix cmd --app indexer iex -S mix
fi


if [[ $COMMAND == "start-web" ]]; then

  echo -e ">> Running Web ..."
  #screen -S blockscout-indexer -d -m mix cmd --app block_scout_web mix phx.server
  #screen -ls
  mix cmd --app block_scout_web mix phx.server
fi