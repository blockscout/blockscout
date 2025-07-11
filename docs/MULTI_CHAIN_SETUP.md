# Multi-Chain Blockscout Setup

This setup follows Blockscout's standard patterns for supporting multiple blockchain networks while maintaining alignment with upstream.

## Directory Structure

```
explorer/
├── configs/
│   ├── chains/          # Chain definitions (JSON)
│   │   ├── lux.json
│   │   ├── zoo.json
│   │   └── spc.json
│   └── envs/           # Environment configs (following Blockscout pattern)
│       ├── .env.lux
│       ├── .env.zoo
│       └── .env.spc
├── docker-compose/
│   ├── docker-compose.unified.yml  # Single compose file for all chains
│   └── envs/                      # Shared environment files
├── scripts/
│   ├── run-chain.sh              # Run specific chain
│   └── build-images.sh           # Build branded images
└── docker/
    └── Dockerfile.luxfi          # LuxFi branded image
```

## Running Different Chains

### Start a specific chain
```bash
cd /home/z/explorer/scripts
./run-chain.sh lux up -d        # Start LUX network explorer
./run-chain.sh zoo up -d        # Start ZOO network explorer
./run-chain.sh spc up -d        # Start SPC network explorer
```

### Stop a chain
```bash
./run-chain.sh lux down
```

### View logs
```bash
./run-chain.sh lux logs -f backend
```

## Port Assignments

| Network | Frontend | Backend | Microservices Base |
|---------|----------|---------|-------------------|
| LUX     | 3000     | 4000    | 8150-8155        |
| ZOO     | 3001     | 4001    | 8160-8165        |
| SPC     | 3002     | 4002    | 8170-8175        |

## Adding a New Chain

1. Create chain definition:
```bash
cp configs/chains/lux.json configs/chains/newchain.json
# Edit the configuration
```

2. Create environment file:
```bash
cp configs/envs/.env.lux configs/envs/.env.newchain
# Update chain-specific settings
```

3. Run the new chain:
```bash
./scripts/run-chain.sh newchain up -d
```

## Building Branded Images

```bash
cd /home/z/explorer/scripts
./build-images.sh 8.1.1
```

This creates:
- `ghcr.io/luxfi/blockscout:8.1.1`
- `ghcr.io/luxfi/blockscout:latest`
- `ghcr.io/luxfi/blockscout:8.1.1-lux`
- `ghcr.io/luxfi/blockscout:8.1.1-zoo`
- `ghcr.io/luxfi/blockscout:8.1.1-spc`

## Configuration Management

### Chain Configuration (configs/chains/*.json)
- Basic chain metadata
- RPC endpoints
- Port assignments
- Database names
- Branding/theme

### Environment Files (configs/envs/.env.*)
- Follows Blockscout's standard ENV pattern
- Chain-specific overrides
- Compatible with upstream tools

### Shared Configuration
- Common settings in `docker-compose/envs/common-*.env`
- Microservice configurations shared across chains
- Database connection patterns

## Advantages of This Approach

1. **Upstream Alignment**: Uses Blockscout's standard environment variable patterns
2. **Single Codebase**: One docker-compose file serves all chains
3. **Easy Maintenance**: Update Blockscout version in one place
4. **Chain Isolation**: Each chain runs in its own namespace
5. **Flexible Deployment**: Can run multiple chains on same host
6. **Branded Images**: Custom images while maintaining compatibility

## Integration with Upstream

This setup allows easy integration with Blockscout's tools:
- Use their preset sync scripts
- Compatible with their deployment patterns
- Can contribute chain configs back to upstream
- Follows their multi-chain conventions

## Database Management

Each chain uses separate databases:
- `explorer_luxnet`, `explorer_zoonet`, `explorer_spcnet`
- `stats_luxnet`, `stats_zoonet`, `stats_spcnet`
- `user_ops_luxnet`, `user_ops_zoonet`, `user_ops_spcnet`

All use the shared PostgreSQL instance with proper isolation.

## Next Steps

1. Migrate existing deployments to this structure
2. Set up automated builds for branded images
3. Create Kubernetes manifests using this pattern
4. Submit chain configurations to Blockscout upstream