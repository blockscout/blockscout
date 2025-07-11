# Aligning with Blockscout Upstream

This document shows how each network fork can stay aligned with Blockscout upstream while maintaining their own customizations.

## Blockscout's Network Configuration Pattern

Blockscout organizes network configurations in environment files. Each network should follow this pattern:

### 1. Environment File Structure

Create `.env` files in `docker-compose/envs/` following Blockscout's naming:

```bash
# Backend configuration
common-blockscout.env

# Frontend configuration  
common-frontend.env

# Microservices
common-stats.env
common-smart-contract-verifier.env
common-visualizer.env
common-user-ops-indexer.env
```

### 2. Standard Environment Variables

Use Blockscout's standard variable names:

#### Backend (common-blockscout.env)
```env
# Network Identity
CHAIN_ID=96369
COIN=LUX
COIN_NAME=LUX

# RPC Configuration
ETHEREUM_JSONRPC_VARIANT=geth
ETHEREUM_JSONRPC_HTTP_URL=http://your-rpc-endpoint
ETHEREUM_JSONRPC_TRACE_URL=http://your-rpc-endpoint
ETHEREUM_JSONRPC_WS_URL=ws://your-rpc-endpoint

# Database
DATABASE_URL=postgresql://user:pass@host:5432/dbname

# API Configuration
API_V2_ENABLED=true
API_V1_READ_METHODS_DISABLED=false
API_V1_WRITE_METHODS_DISABLED=false
```

#### Frontend (common-frontend.env)
```env
# Network Display
NEXT_PUBLIC_NETWORK_NAME=LUX Network
NEXT_PUBLIC_NETWORK_SHORT_NAME=LUX
NEXT_PUBLIC_NETWORK_ID=96369
NEXT_PUBLIC_NETWORK_CURRENCY_NAME=LUX
NEXT_PUBLIC_NETWORK_CURRENCY_SYMBOL=LUX
NEXT_PUBLIC_NETWORK_CURRENCY_DECIMALS=18

# Branding
NEXT_PUBLIC_NETWORK_LOGO=https://your-domain/logo.svg
NEXT_PUBLIC_NETWORK_ICON=https://your-domain/icon.svg

# Features
NEXT_PUBLIC_IS_TESTNET=false
NEXT_PUBLIC_HAS_USER_OPS=true
```

### 3. Docker Compose Structure

Keep the standard Blockscout docker-compose structure:

```yaml
version: '3.9'

services:
  backend:
    image: ghcr.io/blockscout/blockscout:${DOCKER_TAG:-latest}
    env_file:
      - ./envs/common-blockscout.env
    ports:
      - 4000:4000

  frontend:
    image: ghcr.io/blockscout/frontend:${DOCKER_TAG:-latest}
    env_file:
      - ./envs/common-frontend.env
    ports:
      - 3000:3000

  # Other services...
```

### 4. Minimal Modifications

To stay aligned with upstream:

1. **Don't modify core files** - Use environment variables for configuration
2. **Don't change service names** - Keep backend, frontend, stats, etc.
3. **Use standard ports** - Or remap them in docker-compose
4. **Follow naming conventions** - For environment variables and files

### 5. Custom Branding

Add branding without modifying code:

```bash
# Logo files
frontend/public/images/
├── network_logo.svg
├── network_logo_dark.svg
└── favicon.ico

# Set via environment
NEXT_PUBLIC_NETWORK_LOGO=/images/network_logo.svg
NEXT_PUBLIC_NETWORK_LOGO_DARK=/images/network_logo_dark.svg
```

### 6. Contributing Back to Upstream

If your network becomes popular, you can contribute to Blockscout:

1. Create a PR to add your network config:
   ```
   blockscout/frontend/configs/envs/.env.yournetwork
   ```

2. Add to their featured networks:
   ```
   blockscout/frontend/configs/featured-networks/yournetwork.json
   ```

3. Submit chain metadata:
   ```json
   {
     "name": "YourNetwork",
     "chainId": 12345,
     "shortName": "YN",
     "networkId": 12345,
     "nativeCurrency": {
       "name": "YourToken",
       "symbol": "YT",
       "decimals": 18
     }
   }
   ```

## Benefits of This Approach

1. **Easy Updates**: Pull latest Blockscout without conflicts
2. **Standard Tooling**: Use Blockscout's deployment scripts
3. **Community Support**: Get help from Blockscout community
4. **Professional**: Shows you follow industry standards
5. **Future-proof**: Ready for Blockscout's new features

## Example: Adding a New Network

```bash
# 1. Fork Blockscout
git clone https://github.com/yourorg/blockscout-fork

# 2. Create your env files
cp docker-compose/envs/common-blockscout.env.example docker-compose/envs/common-blockscout.env
# Edit with your network details

# 3. Add simple run scripts
cat > scripts/run-mainnet.sh << 'EOF'
#!/bin/bash
cd docker-compose
docker-compose up -d
EOF

# 4. Deploy
./scripts/run-mainnet.sh
```

This way, each network maintains their own fork but stays compatible with Blockscout's ecosystem.