#!/bin/bash

# Run LUX Network Testnet Explorer
# This script starts the Blockscout explorer for LUX testnet

cd "$(dirname "$0")/.."

echo "Starting LUX Network Testnet Explorer..."
echo "  Chain ID: 96368"
echo "  Frontend: http://localhost:3010"
echo "  Backend API: http://localhost:4010"
echo ""

# Start services
docker-compose -f compose.testnet.yml up -d

echo ""
echo "LUX Testnet Explorer is starting..."
echo "View logs: docker-compose -f compose.testnet.yml logs -f"