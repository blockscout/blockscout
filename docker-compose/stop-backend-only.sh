#!/bin/bash

echo "🛑 Stopping Blockscout Backend Services for Sepolia Testnet..."

docker compose -f sepolia-backend-only.yml down

echo "✅ Blockscout Backend Services stopped successfully!"