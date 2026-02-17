# Signet Orders Fetcher

This module indexes Order and Filled events from Signet's cross-chain order protocol.

## Overview

The Signet protocol enables cross-chain orders between a rollup (L2) and its host chain (L1). This fetcher:

1. **Parses Order events** from the RollupOrders contract on L2
2. **Parses Filled events** from both RollupOrders (L2) and HostOrders (L1) contracts
3. **Stores events independently** for querying and analytics
4. **Handles chain reorgs** gracefully by removing invalidated data

**Note:** Orders and fills are indexed independently. Direct correlation between orders
and their corresponding fills is not possible at the indexer level — only block-level
coordination is available. This is a protocol-level constraint.

## Event Types

### RollupOrders Contract (L2)

- `Order(uint256 deadline, Input[] inputs, Output[] outputs)` - New order created
- `Filled(Output[] outputs)` - Order filled on rollup
- `Sweep(address recipient, address token, uint256 amount)` - Remaining funds swept

### HostOrders Contract (L1)

- `Filled(Output[] outputs)` - Order filled on host chain

## Data Structures

**Input:** `(address token, uint256 amount)`
**Output:** `(address token, uint256 amount, address recipient, uint32 chainId)`

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
| transaction_hash | bytea | Primary key (part 1), transaction containing the order |
| log_index | integer | Primary key (part 2), log index within transaction |
| deadline | bigint | Order deadline timestamp |
| block_number | bigint | Block where order was created |
| inputs_json | text | JSON array of inputs |
| outputs_json | text | JSON array of outputs (includes chainId) |
| sweep_recipient | bytea | Sweep recipient (if any) |
| sweep_token | bytea | Sweep token (if any) |
| sweep_amount | numeric | Sweep amount (if any) |

### signet_fills

Stores Filled events from both chains.

| Column | Type | Description |
|--------|------|-------------|
| chain_type | enum | Primary key (part 1), 'rollup' or 'host' |
| transaction_hash | bytea | Primary key (part 2), transaction containing the fill |
| log_index | integer | Primary key (part 3), log index within transaction |
| block_number | bigint | Block where fill occurred |
| outputs_json | text | JSON array of filled outputs (includes chainId) |

## chainId Semantics

The Output struct includes a `chainId` field with different semantics depending on context:

- **In Order events (origin chain):** `chainId` is the **destination chain** where assets should be delivered
- **In Filled events (destination chain):** `chainId` is the **origin chain** where the order was created

This semantic difference is inherent to the protocol and must be considered when interpreting the data.

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
