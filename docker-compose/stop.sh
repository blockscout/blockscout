#!/bin/bash

if (($# != 1)); then
    echo "Arguments: <Specify the network config to use. Can be 'localnet' (without quote) or any public network"
else
    if [[ "$1" == "localnet" ]]; then
        docker compose down
    else
        docker compose --profile publicnet down
    fi
fi
