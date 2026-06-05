# @blockscout/api-types

TypeScript types generated from Blockscout OpenAPI specs via [openapi-typescript](https://openapi-ts.dev):

- **publicApi** — default public API (`BlockScoutWeb.Specs.Public`, no `CHAIN_TYPE`)
- **privateApi** — account API (`BlockScoutWeb.Specs.Private`)
- **chain namespaces** — chain-specific public API (`CHAIN_TYPE` set; matches [generate-swagger.yml](https://github.com/blockscout/blockscout/blob/master/.github/workflows/generate-swagger.yml), excluding deprecated MUD)

Build artifacts (`openapi/`, `dist/`) are gitignored; run `npm run build` after clone.

## Prerequisites

- **Elixir / Mix** at the Blockscout repo root (compiled `block_scout_web` app)
- **Node.js** 18+ (for `openapi-typescript`)

## Generate

From this directory:

```bash
npm install
npm run build
```

`build` runs:

1. **`generate:spec`** — `mix openapi.spec.yaml` for public, private, and each chain type
2. **`generate:types`** — `openapi-typescript` writes matching files under `dist/`

## Usage

Types are grouped by spec name in the package entry:

```ts
import type { publicApi, privateApi, arbitrum, optimismCelo } from "@blockscout/api-types";

type AddressResponse = publicApi.components["schemas"]["AddressResponse"];

type GetAddressParams =
  publicApi.paths["/v2/addresses/{address_hash_param}"]["get"]["parameters"];

type ArbitrumPath = arbitrum.paths[keyof arbitrum.paths];
```

`publicApi` / `privateApi` avoid TypeScript reserved words (`public`, `private`). `optimism-celo` is exported as `optimismCelo` (hyphen is invalid in identifiers).

Point your app at this package via `file:../types-package` or your monorepo workspace.

## Chain types

Synced with `.github/workflows/generate-swagger.yml` via `scripts/chain-types.sh`:

`arbitrum`, `arc`, `blackfort`, `ethereum`, `filecoin`, `neon`, `optimism`, `optimism-celo`, `rsk`, `scroll`, `shibarium`, `stability`, `suave`, `zetachain`, `zilliqa`, `zksync`

When CI adds or removes a chain type, update `scripts/chain-types.sh` and `index.ts`.
