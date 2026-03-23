# Agent Guidelines for Blockscout

## Separate API / Indexer Mode Architecture

Blockscout supports running as a single combined application or as separate API and indexer instances via the `APPLICATION_MODE` environment variable.

### Mode Configuration

`APPLICATION_MODE` environment variable (defined in `config/config_helper.exs`):
- `all` (default) — both API and indexer run together
- `api` — API-only instance, no indexing
- `indexer` — indexer-only instance, no API serving

The current mode is accessible via `Explorer.mode()` (defined in `apps/explorer/lib/explorer.ex`), which returns `:all`, `:api`, `:indexer`, or `:media_worker`.

`:media_worker` is a special standalone mode for NFT media processing. It is not set via `APPLICATION_MODE` — it activates when `nft_media_handler[:standalone_media_worker?]` is true, overriding the configured mode. In this mode, `Explorer.Application` starts only libcluster — no base_children or configurable_children. The process mode filtering rules below do not apply to `:media_worker`.

Related environment variables:
- `DISABLE_INDEXER` — forces indexer off (auto-set when `APPLICATION_MODE=api`)
- `DISABLE_API` — forces API off (compile-time, controls `BlockScoutWeb.Endpoint`)

### Rules for Assigning Processes to Modes

When adding or modifying processes started by `Explorer.Application`, `Indexer.Application`, or `BlockScoutWeb.Application`, follow these rules:

**Start in `:indexer` mode only:**
- Active periodic updaters — GenServers that periodically query the DB and write results to `last_fetched_counters` table (e.g., `ContractsCount`, `NewPendingTransactionsCount`, `Transactions24hCount`). The API side reads directly from the DB table without needing a local process.
- Data migrators (`Explorer.Migrator.*`) — one-time or ongoing data transformations.
- Catalogers and tag importers (`AddressTag.Cataloger`, `CertifiedSmartContractCataloger`).
- Block gap scanning (`MinMissingBlockNumber`).
- Indexer-specific caches that are written and read by indexer only (`TransactionActionTokensData`, `TransactionActionUniswapPools`, `LatestL1BlockNumber`).

**Start in `:api` mode only:**
- Passive on-demand ETS/in-memory caches — GenServers that manage an ETS table and populate it on API request (e.g., `AddressTransactionsCount`, `TokenHoldersCount`, `BlockBurntFeeCount`, `AverageBlockTime`). ETS is local to the process, so these must run on the instance serving requests.
- On-demand fetchers triggered by API requests (`CheckBytecodeMatchingOnDemand`, `FetchValidatorInfoOnDemand`, `LookUpSmartContractSourcesOnDemand`).
- API access control (`AddressesBlacklist`).
- Contract verification tooling (`SolcDownloader`, `VyperDownloader`).
- Read-only DB replicas (`Explorer.Repo.Replica1`).
- API-only caches (`OptimismFinalizationPeriod`, `CeloEpochs`, `Rootstock.LockedBTCCount`).

**Start in both modes (`:all`, `:api`, `:indexer`):**
- Core infrastructure: main `Explorer.Repo`, `Explorer.Vault`, `Registry.ChainEvents`, `Redix`.
- Event system: `Explorer.Chain.Events.Listener` (mode-controlled via its own `:enabled` config).
- Cluster discovery (`libcluster`) — needed for node communication in separate mode.

### Helper Functions in Explorer.Application

- `configure(process)` — starts if `Application.get_env(:explorer, process)[:enabled] == true`. No mode check.
- `configure_mode_dependent_process(process, mode)` — starts if `:enabled` is true AND `Explorer.mode()` matches. Use for processes that have `:enabled` config in `runtime.exs`.
- `only_in_mode(process, mode)` — starts if `Explorer.mode()` matches. No `:enabled` check. Use for processes without `:enabled` config (e.g., repos, downloaders, unconditional entries).
- `configure_chain_type_dependent_process(process, chain_type)` — starts if chain type matches. Can be piped with mode filters.

Piping pattern for combined restrictions:
```elixir
SomeProcess
|> configure_mode_dependent_process(:indexer)
|> configure_chain_type_dependent_process(:optimism)
```

### Cache Pattern Reference

How to distinguish active updaters from passive caches when deciding the mode:
- **Active periodic updater**: has `schedule_next_consolidation()`, `handle_info(:consolidate)`, writes to `last_fetched_counters` via `LastFetchedCounter.upsert()` -> `:indexer`
- **Passive on-demand ETS cache**: has `fetch()` with cache expiry check, stores in ETS via `Helper.put_into_ets_cache()`, may update model columns -> `:api`
- **MapCache (ConCache)**: uses `use Explorer.Chain.MapCache`, implements `handle_fallback` -> `:api`
