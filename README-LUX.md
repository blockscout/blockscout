# LUX Network Explorer

Official blockchain explorer for LUX Network, powered by Blockscout.

## Quick Start

### Mainnet Explorer
```bash
cd scripts
./run-mainnet.sh
```
- Frontend: https://explore.lux.network (http://localhost:3000)
- API: https://api-explore.lux.network (http://localhost:4000)

### Testnet Explorer
```bash
cd scripts
./run-testnet.sh
```
- Frontend: https://testnet.explore.lux.network (http://localhost:3010)
- API: https://api-testnet.explore.lux.network (http://localhost:4010)

## Network Information

| Network | Chain ID | RPC Endpoint |
|---------|----------|--------------|
| Mainnet | 96369 | http://127.0.0.1:9650/ext/bc/dnmzhuf6poM6PUNQCe7MWWfBdTJEnddhHRNXz2x7H6qSmyBEJ/rpc |
| Testnet | 96368 | http://127.0.0.1:9650/ext/bc/2sdADEgBC3NjLM4inKc1hY1PQpCT3JVyGVJxdmcq6sqrDndjFG/rpc |

## Configuration

Configuration files are in `docker-compose/envs/`:
- `common-blockscout.env` - Backend settings
- `common-frontend.env` - Frontend settings
- `common-stats.env` - Statistics service

## Development

### Stop Services
```bash
# Mainnet
cd docker-compose && docker-compose down

# Testnet
cd docker-compose && docker-compose -p explorer-lux-testnet down
```

### View Logs
```bash
# Mainnet
cd docker-compose && docker-compose logs -f

# Testnet  
cd docker-compose && docker-compose -p explorer-lux-testnet logs -f
```

### Update Blockscout
1. Update `DOCKER_TAG` in docker-compose.yml
2. Run: `docker-compose pull`
3. Restart: `./scripts/run-mainnet.sh`

## Database

Using existing PostgreSQL databases:
- Mainnet: `explorer_luxnet` (1,082,781+ blocks indexed)
- Testnet: `explorer_luxtest`

## Support

- Website: https://lux.network
- Discord: https://discord.gg/luxnetwork
- GitHub: https://github.com/luxfi/explorer

## License

Same as Blockscout - GPL-3.0