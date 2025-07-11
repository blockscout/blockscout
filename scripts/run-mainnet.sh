#!/bin/bash

# Run LUX Network Mainnet Explorer
# This script starts the Blockscout explorer for LUX mainnet

cd "$(dirname "$0")/.."

echo "Starting LUX Network Mainnet Explorer..."
echo "  Chain ID: 96369"
echo "  Frontend: http://localhost:3000"
echo "  Backend API: http://localhost:4000"
echo ""

# Start services
docker-compose -f compose.mainnet.yml up -d

echo ""
echo "LUX Mainnet Explorer is starting..."
echo "View logs: docker-compose -f compose.mainnet.yml logs -f"