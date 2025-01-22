#!/bin/bash

docker compose down
sudo rm -rf services/*-data
rm -rf services/dets
rm -rf services/logs

if [[ "$1" == "--restart" ]]; then
    if [[ "$2" == "localnet" ]]; then
        ./start.sh localnet
    elif [[ "$2" == "testnet" ]]; then
        ./start.sh testnet
    else
        echo "unknown network, not restarting"
    fi
fi
