# Signet SDK ABI Extractor

This tool extracts ABI definitions from the `@signet-sh/sdk` npm package for use in the Elixir-based Blockscout indexer.

## Overview

Blockscout is an Elixir application, but the Signet protocol's canonical ABI definitions are maintained in the TypeScript SDK (`@signet-sh/sdk`). This tool bridges that gap by:

1. Installing the SDK as an npm dependency
2. Extracting ABIs as JSON files
3. Storing them in `apps/explorer/priv/contracts_abi/signet/`

The Elixir indexer then loads these JSON files via `Indexer.Fetcher.Signet.Abi`.

## Usage

### Initial Setup

```bash
cd tools/signet-sdk
npm install
npm run extract
```

### Updating ABIs

When the SDK is updated:

1. Update the version in `package.json`
2. Run:
   ```bash
   npm install
   npm run extract
   ```
3. Commit the updated JSON files in `apps/explorer/priv/contracts_abi/signet/`

## Extracted ABIs

The following ABIs are extracted from `@signet-sh/sdk`:

| File | Contract | Description |
|------|----------|-------------|
| `rollup_orders.json` | RollupOrders | L2 order creation and fills |
| `host_orders.json` | HostOrders | L1 fills |
| `passage.json` | Passage | L1→L2 bridging |
| `rollup_passage.json` | RollupPassage | L2→L1 bridging |
| `permit2.json` | Permit2 | Gasless token approvals |
| `weth.json` | WETH | Wrapped ETH |
| `zenith.json` | Zenith | Block submission |
| `transactor.json` | Transactor | Cross-chain transactions |
| `bundle_helper.json` | BundleHelper | Bundle utilities |
| `events_index.json` | — | Index of all events |

## Event Signatures

Key events tracked by the indexer (from `rollup_orders.json`):

- **Order**: `Order(uint256 deadline, (address,uint256)[] inputs, (address,uint256,address,uint32)[] outputs)`
- **Filled**: `Filled((address,uint256,address,uint32)[] outputs)`
- **Sweep**: `Sweep(address indexed recipient, address indexed token, uint256 amount)`

## Architecture

```
@signet-sh/sdk (npm)
       ↓
tools/signet-sdk/extract-abis.mjs
       ↓
apps/explorer/priv/contracts_abi/signet/*.json
       ↓
Indexer.Fetcher.Signet.Abi (Elixir module)
       ↓
Indexer.Fetcher.Signet.EventParser
```
