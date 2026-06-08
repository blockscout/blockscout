# @blockscout/api-types

TypeScript types generated from Blockscout OpenAPI specs via [openapi-typescript](https://openapi-ts.dev):

- **publicApi** — default public API (`BlockScoutWeb.Specs.Public`, no `CHAIN_TYPE`)
- **privateApi** — account API (`BlockScoutWeb.Specs.Private`)
- **chain namespaces** — chain-specific public API (`CHAIN_TYPE` set; matches [generate-swagger.yml](https://github.com/blockscout/blockscout/blob/master/.github/workflows/generate-swagger.yml), excluding deprecated MUD)
- **merged** — every schema from all specs above combined into one namespace (for universal frontends that handle any chain type at runtime); see [Merged schemas](#merged-schemas)

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

## Merged schemas

`scripts/merge-specs.mjs` merges all generated specs (public → private → chains alphabetically) into `openapi/merged.yaml`, which compiles to `dist/merged.schema.ts` (exported as `merged`). Specs must already exist; regenerate them with `generate:spec` only when the API changes:

```bash
npm run generate:spec:merged   # writes openapi/merged.yaml
npx openapi-typescript openapi/merged.yaml -o dist/merged.schema.ts --export-type --alphabetize=true
```

```ts
import type { merged } from "@blockscout/api-types";

// Includes the public base plus `arbitrum?`, `zksync?`, blob fields, etc. — all optional.
type Transaction = merged.components["schemas"]["Transaction"];

// Paths/operations are merged too, referencing the merged models:
type Tx = merged.paths["/v2/transactions/{transaction_hash_param}"]["get"]["responses"][200];
```

Merge semantics:

- **Schemas** — `properties` are unioned; `required` is the intersection across specs defining a schema, so chain-specific properties are optional. Sub-objects defined in a single spec keep their `required` (e.g. `arbitrum.gas_used_for_l1` stays required when `arbitrum` is present). `enum` values are unioned (e.g. `transaction_types` gains chain-specific entries).
- **Paths & operations** — unioned across specs; chain-only endpoints (e.g. `/v2/arbitrum/batches`) are included. Shared operations are deep-merged, with `parameters` matched by (in, name) and their `schema`s unioned (e.g. enum query params gain chain-specific values). All operation `$ref`s point at `components.schemas`, so they reference the merged models automatically.
- Irreconcilable schema shapes (e.g. ethereum redefines `Status` as a beacon-deposit enum) become `anyOf` unions and are reported as warnings on stderr.

Point your app at this package via `file:../types-package` or your monorepo workspace.

## Chain types

Synced with `.github/workflows/generate-swagger.yml` via `scripts/chain-types.sh`:

`arbitrum`, `arc`, `blackfort`, `ethereum`, `filecoin`, `neon`, `optimism`, `optimism-celo`, `rsk`, `scroll`, `shibarium`, `stability`, `suave`, `zetachain`, `zilliqa`, `zksync`

When CI adds or removes a chain type, update `scripts/chain-types.sh` and `index.ts`.
