---
name: run-server
description: "Use this skill when you need to start, launch, or run the Blockscout backend server (mix phx.server). Trigger on phrases like 'start the server', 'run blockscout', 'launch the API', 'start indexing', 'run phx.server', or when the user wants to see the explorer running locally. Also use when preparing environment configuration for running the server, or when a previous server start failed due to missing env vars. Also use when running the indexer locally against a real network or public/paid RPC endpoint, when the RPC node returns rate-limit errors (429, 'too many requests'), or when the user wants to test block, transaction, receipt or log import with fewer JSON-RPC requests or lower local resource use."
---

# Running the Blockscout server

Starting the Blockscout backend requires environment variables configured for the target chain. The commands below show raw `mix` invocations with env vars sourced from an env file — run them in whatever environment has Elixir available (host, devcontainer, CI, etc.).

## Step 1: Prepare the env file

Create an env file in `tmp/` with a descriptive name reflecting the chain and network, e.g. `tmp/ethereum-sepolia.env`, `tmp/arbitrum-one.env`.

### Essential variables

Every env file needs at least these three:

```bash
CHAIN_TYPE=ethereum
DATABASE_URL=postgresql://postgres:postgres@db:5432/app
ETHEREUM_JSONRPC_HTTP_URL=https://ethereum-sepolia-rpc.publicnode.com
```

- `CHAIN_TYPE` — determines which chain-specific modules are active. This is read at **compile time** — see the `compile-project` skill for valid values and recompilation instructions.
- `DATABASE_URL` — connection string for PostgreSQL. The devcontainer's default is `postgresql://postgres:postgres@db:5432/app`; adjust for your environment.
- `ETHEREUM_JSONRPC_HTTP_URL` — the RPC endpoint for the chain being indexed. The user must provide this; there is no sensible default.

### API-only mode

To run the server without the indexer (useful for API development), add:

```bash
DISABLE_INDEXER=true
```

In this mode `ETHEREUM_JSONRPC_HTTP_URL` is not strictly required, but some API responses will be incomplete without historical indexed data.

### Low-RPC local indexing profile

Use this profile when the indexer runs on a local machine against a real network and the goal is to test the block import pipeline (blocks, transactions, receipts, logs, token transfers). RPC providers rate-limit aggressively, and a default indexer start fires many parallel requests from background fetchers that such a test does not need. The profile cuts those requests and lowers database, memory and external-service use.

Build the env file from the template:

```bash
cp .claude/skills/run-server/references/low-rpc-local.env tmp/<name>.env
```

Then append the three essential variables above. Two values need a decision per network:

- `ETHEREUM_JSONRPC_VARIANT` — set it to the node's client. The template uses `geth`.
- `ETHEREUM_JSONRPC_RECEIPTS_BY_BLOCK=true` — switches receipts to one `eth_getBlockReceipts` call per block. Remove the line if the node or provider does not support that method.

If rate-limit errors persist, lower `INDEXER_CATCHUP_BLOCKS_CONCURRENCY` or raise `INDEXER_CATCHUP_BLOCK_INTERVAL` before touching anything else; those two set the main request rate.

With this profile the database intentionally lacks token metadata, address coin and token balances, contract bytecode and internal transactions. Do not treat empty fields of that kind as a bug. If the task needs one of them, remove the matching `INDEXER_DISABLE_*` line from the env file.

Variable names drift between releases. When editing the template, confirm each name still appears in `config/runtime.exs` (or in `apps/indexer/config/{dev,prod}/<variant>.exs` for `INDEXER_CATCHUP_BLOCK_INTERVAL`); an unknown name is silently ignored.

### Finding additional variables

Many features require additional configuration (rate limits, pool sizes, disabled fetchers, microservice URLs, etc.). Consult these sources in order:

1. **`.devcontainer/.blockscout_config.example`** — a local example with common development variables for batch sizes, concurrency, disabled fetchers, and pool sizes. Read this file first to see what a typical dev configuration looks like.

2. **`config/runtime.exs`** — the authoritative source of every env var the backend reads at runtime. Search this file for the variable name or feature area (e.g., grep for `INDEXER_DISABLE` to find all fetcher toggle vars).

3. **Blockscout docs** (only when the above are insufficient) — these pages document the full variable catalog:
   - `https://docs.blockscout.com/setup/env-variables/backend-env-variables.md` — core variables
   - `https://docs.blockscout.com/setup/env-variables/backend-envs-chain-specific.md` — chain-specific variables
   - `https://docs.blockscout.com/setup/env-variables/backend-envs-integrations.md` — third-party integrations

   These pages are large. Do not fetch them in full. Instead, use WebFetch to retrieve the page and search for the specific variable or feature area you need.

## Step 2: Ensure the project is compiled

The project must be compiled with a `CHAIN_TYPE` matching the env file. Use the `compile-project` skill — it covers incremental compile, full recompile (after chain-type switch), and first-time initialization (which generates the SSL certificate needed by Phoenix).

## Step 3: Initialize the database (if needed)

If the database doesn't exist or hasn't been migrated:

```bash
set -a; source tmp/<name>.env; set +a; mix do ecto.create, ecto.migrate
```

## Step 4: Start the server

This is a long-running process — always use `run_in_background: true` on the Bash tool call:

```bash
set -a; source tmp/<name>.env; set +a; mix phx.server
```

The server listens on `http://localhost:4000` by default.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `(UndefinedFunctionError)` for chain-specific module | `CHAIN_TYPE` mismatch | Use the `compile-project` skill to do a full recompile with the correct `CHAIN_TYPE` |
| `connection refused` on port 5432 | Database not running | Ensure PostgreSQL is available and `DATABASE_URL` is correct |
| `database "app" does not exist` | Database not created yet | Run `mix do ecto.create, ecto.migrate` with the env file sourced |
| Server starts but no blocks indexed | RPC endpoint unreachable or wrong | Verify `ETHEREUM_JSONRPC_HTTP_URL` is correct and accessible |
| `(MatchError)` in variant config loading | `ETHEREUM_JSONRPC_VARIANT` mismatch | Set `ETHEREUM_JSONRPC_VARIANT` explicitly (defaults to `geth` for most chain types) |
| SSL cert missing / Phoenix HTTPS error | First-time setup incomplete | Use the `compile-project` skill's first-time initialization flow |
