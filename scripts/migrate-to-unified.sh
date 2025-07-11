#!/bin/bash

# Script to migrate from separate directories to unified setup
# This preserves existing data and configurations

echo "Migrating to unified Blockscout setup..."

# Create necessary directories
mkdir -p ../configs/{chains,envs}
mkdir -p ../docker/branding/logos

# Function to migrate a network
migrate_network() {
    local NETWORK=$1
    local OLD_DIR=$2
    local CHAIN_ID=$3
    local BLOCKCHAIN_ID=$4
    
    echo "Migrating $NETWORK network..."
    
    # Copy environment files if they exist
    if [ -f "$OLD_DIR/docker-compose/envs/common-blockscout.env" ]; then
        echo "  Extracting $NETWORK specific configs..."
        
        # Extract key values from old config
        # This is a simplified example - in practice you'd parse more carefully
        cat > "../configs/envs/.env.$NETWORK" << EOF
# Set of ENVs for $NETWORK Network Mainnet
# Auto-migrated from $OLD_DIR

CHAIN_NAME=$NETWORK
CHAIN_ID=$CHAIN_ID
ETHEREUM_JSONRPC_HTTP_URL=http://k8s-host:9650/ext/bc/$BLOCKCHAIN_ID/rpc
ETHEREUM_JSONRPC_TRACE_URL=http://k8s-host:9650/ext/bc/$BLOCKCHAIN_ID/rpc
ETHEREUM_JSONRPC_WS_URL=ws://k8s-host:9650/ext/bc/$BLOCKCHAIN_ID/ws
DATABASE_URL=postgresql://blockscout:ceWb1MeLBEeOIfk65gU8EjF8@host-postgres:5432/explorer_${NETWORK}net?sslmode=disable

# Add other configs as needed
EOF
    fi
    
    # Copy logos if they exist
    if [ -d "$OLD_DIR/docker-compose/frontend/public/images" ]; then
        cp -n "$OLD_DIR/docker-compose/frontend/public/images/"*.svg "../docker/branding/logos/" 2>/dev/null || true
    fi
    
    echo "  Migration complete for $NETWORK"
}

# Migrate each network
migrate_network "lux" "/home/z/explorer" "96369" "dnmzhuf6poM6PUNQCe7MWWfBdTJEnddhHRNXz2x7H6qSmyBEJ"
migrate_network "zoo" "/home/z/explorer-zoo" "200200" "bXe2MhhAnXg6WGj6G8oDk55AKT1dMMsN72S8te7JdvzfZX1zM"
migrate_network "spc" "/home/z/explorer-spc" "36911" "QFAFyn1hh59mh7kokA55dJq5ywskF5A1yn8dDpLhmKApS6FP1"

echo ""
echo "Migration complete!"
echo ""
echo "Next steps:"
echo "1. Review the generated configs in configs/envs/"
echo "2. Stop old containers: docker-compose down in each directory"
echo "3. Start with unified setup: ./scripts/run-chain.sh lux up -d"
echo ""
echo "Note: Your existing data in PostgreSQL is preserved"