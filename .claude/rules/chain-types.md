## Supported CHAIN_TYPE values

The canonical source is `@supported_chain_identities` in `config/config_helper.exs`.

Valid `CHAIN_TYPE` environment variable values and their resolved identities:

| `CHAIN_TYPE` | Resolved identity |
|---|---|
| *(unset)* | `:default` |
| `arbitrum` | `:arbitrum` |
| `arc` | `:arc` |
| `blackfort` | `:blackfort` |
| `ethereum` | `:ethereum` |
| `filecoin` | `:filecoin` |
| `neon` | `:neon` |
| `optimism` | `:optimism` |
| `optimism-celo` | `{:optimism, :celo}` |
| `rsk` | `:rsk` |
| `scroll` | `:scroll` |
| `shibarium` | `:shibarium` |
| `stability` | `:stability` |
| `suave` | `:suave` |
| `zetachain` | `:zetachain` |
| `zilliqa` | `:zilliqa` |
| `zksync` | `:zksync` |
