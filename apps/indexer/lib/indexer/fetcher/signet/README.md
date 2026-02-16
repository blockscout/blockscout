# Signet Orders Fetcher

This module indexes Order and Filled events from Signet's cross-chain order protocol.

## Overview

The Signet protocol enables cross-chain orders between a rollup (L2) and its host chain (L1). This fetcher:

1. **Parses Order events** from the RollupOrders contract on L2
2. **Parses Filled events** from both RollupOrders (L2) and HostOrders (L1) contracts
3. **Computes outputs_witness_hash** for correlating orders with their fills
4. **Handles chain reorgs** gracefully by removing invalidated data

## Event Types

### RollupOrders Contract (L2)

- `Order(uint256 deadline, Input[] inputs, Output[] outputs)` - New order created
- `Filled(Output[] outputs)` - Order filled on rollup
- `Sweep(address recipient, address token, uint256 amount)` - Remaining funds swept

### HostOrders Contract (L1)

- `Filled(Output[] outputs)` - Order filled on host chain

## Data Structures

**Input:** `(address token, uint256 amount)`
**Output:** `(address recipient, address token, uint256 amount)`

## Configuration

Add to your config:

```elixir
config :indexer, Indexer.Fetcher.Signet.OrdersFetcher,
  enabled: true,
  rollup_orders_address: "0x...",  # RollupOrders contract on L2
  host_orders_address: "0x...",    # HostOrders contract on L1 (optional)
  l1_rpc: "https://...",           # L1 RPC endpoint (optional, for host fills)
  l1_rpc_block_range: 1000,        # Max blocks to fetch per L1 request
  recheck_interval: 15_000,        # Milliseconds between checks
  start_block: 0                   # Starting block for indexing
```

## Database Tables

### signet_orders

Stores Order events with their inputs, outputs, and any associated Sweep data.

| Column | Type | Description |
|--------|------|-------------|
| outputs_witness_hash | bytea | Primary key, keccak256 of outputs |
| deadline | bigint | Order deadline timestamp |
| block_number | bigint | Block where order was created |
| transaction_hash | bytea | Transaction containing the order |
| log_index | integer | Log index within transaction |
| inputs_json | text | JSON array of inputs |
| outputs_json | text | JSON array of outputs |
| sweep_recipient | bytea | Sweep recipient (if any) |
| sweep_token | bytea | Sweep token (if any) |
| sweep_amount | numeric | Sweep amount (if any) |

### signet_fills

Stores Filled events from both chains.

| Column | Type | Description |
|--------|------|-------------|
| outputs_witness_hash | bytea | Part of composite primary key |
| chain_type | enum | 'rollup' or 'host' |
| block_number | bigint | Block where fill occurred |
| transaction_hash | bytea | Transaction containing the fill |
| log_index | integer | Log index within transaction |
| outputs_json | text | JSON array of filled outputs |

## Cross-Chain Correlation

Orders and fills are correlated using `outputs_witness_hash`:

```
outputs_witness_hash = keccak256(concat(keccak256(abi_encode(output)) for output in outputs))
```

This allows matching fills to their original orders even across different chains.

## Reorg Handling

When a chain reorganization is detected:

1. **Rollup reorg**: Deletes all orders and rollup fills from the reorg block onward
2. **Host reorg**: Deletes only host fills from the reorg block onward

The fetcher will re-process the affected blocks after cleanup.

## Metrics

The fetcher logs:
- Number of orders/fills processed per batch
- Block ranges being indexed
- Any parsing or import errors

## Files

- `orders_fetcher.ex` - Main fetcher module
- `event_parser.ex` - ABI decoding and witness hash computation
- `reorg_handler.ex` - Chain reorganization handling
- `utils/db.ex` - Database query utilities
- `orders_fetcher/supervisor.ex` - Supervisor for the fetcher

## Migration

Run the migration to create tables:

```bash
mix ecto.migrate --migrations-path apps/explorer/priv/signet/migrations
```
