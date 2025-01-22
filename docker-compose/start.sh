#!/bin/bash

if (($# != 1)); then
    echo "Arguments: <Specify the network config to use. Must be 'localnet' or 'testnet' (without quote)"
else
    if [[ "$1" == "localnet" ]]; then
        docker compose --env-file envs/localnet.env up --build -d
    elif [[ "$1" == "testnet" ]]; then
        docker compose --env-file envs/testnet.env --profile publicnet up --build -d
    else
        echo "invalid network, exiting"
    fi
fi