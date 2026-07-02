# @blockscout/api-types

TypeScript types generated from Blockscout OpenAPI specs via [openapi-typescript](https://openapi-ts.dev):

- **shorthands** (`schemas`, `operations`, `paths`) — the recommended entry point; flat lookups over the merged spec, spanning every chain type. See [Usage](#usage)
- **merged** — every schema, path, and operation from all specs below combined into one namespace (for universal frontends that handle any chain type at runtime); see [Merged schemas](#merged-schemas)
- **publicApi** — default public API (`BlockScoutWeb.Specs.Public`, no `CHAIN_TYPE`)
- **privateApi** — account API (`BlockScoutWeb.Specs.Private`)
- **chain namespaces** — chain-specific public API (`CHAIN_TYPE` set; matches [generate-swagger.yml](https://github.com/blockscout/blockscout/blob/master/.github/workflows/generate-swagger.yml))

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

### Shorthands (recommended)

Three top-level exports flatten the most common lookups against the merged spec, so you never index through `components["schemas"]` or `["responses"][200]["content"]["application/json"]` by hand. Prefer these for everyday use:

```ts
import type { schemas, operations, paths } from "@blockscout/api-types";

// `schemas` — a model by name (merged across all chains; chain-specific props optional).
type Transaction = schemas["Transaction"];

// `operations` — keyed by short operationId, with `json` / `params` / `requestBody`.
type TxJson = operations["TransactionController.transaction"]["json"];
type TxParams = operations["TransactionController.transaction"]["params"];
type EthCallBody = operations["EthController.eth_call"]["requestBody"];

// `paths` — the 200 `application/json` body keyed by path, then HTTP method.
type Blocks = paths["/api/v2/blocks"]["get"];
```

Notes:

- **operationIds are shortened** — the controller module prefix (`BlockScoutWeb.API.V2.`, `BlockScoutWeb.Account.API.V2.`, `BlockScoutWeb.API.Legacy.`) is stripped, so `BlockScoutWeb.API.V2.TransactionController.transaction` becomes `TransactionController.transaction`.
- `json` is the 200 `application/json` response body; `params` is the request `query`/`path` parameters; `requestBody` is the `application/json` request body (`never` for endpoints without one).
- `paths` only exposes the HTTP methods an endpoint actually defines; missing methods are absent, not `never`.
- All three are derived from `merged`, so they already span every chain type. Reach for the `merged`/per-chain namespaces below only when you need something these don't cover (non-200 responses, response headers, raw path items).

### Merged schemas

The shorthands above are built on the **merged** namespace — every schema, path, and operation from all specs combined, so a universal frontend can handle any chain type at runtime from a single type universe. Import `merged` directly when you need lookups the shorthands don't expose (non-200 responses, response headers, raw path items):

```ts
import type { merged } from "@blockscout/api-types";

// Includes the public base plus `arbitrum?`, `zksync?`, blob fields, etc. — all optional.
type Transaction = merged.components["schemas"]["Transaction"];

// Paths/operations are merged too, referencing the merged models:
type Tx = merged.paths["/api/v2/transactions/{transaction_hash_param}"]["get"]["responses"][200];
```

### Per-spec namespaces

Types are also grouped by spec name in the package entry:

```ts
import type { publicApi, privateApi, arbitrum, optimismCelo } from "@blockscout/api-types";

type AddressResponse = publicApi.components["schemas"]["AddressResponse"];

type GetAddressParams =
  publicApi.paths["/api/v2/addresses/{address_hash_param}"]["get"]["parameters"];

type ArbitrumPath = arbitrum.paths[keyof arbitrum.paths];
```

`publicApi` / `privateApi` avoid TypeScript reserved words (`public`, `private`). `optimism-celo` is exported as `optimismCelo` (hyphen is invalid in identifiers)

## Chain types

Synced with `.github/workflows/generate-swagger.yml` via `scripts/chain-types.sh`:

`arbitrum`, `arc`, `blackfort`, `ethereum`, `filecoin`, `neon`, `optimism`, `optimism-celo`, `rsk`, `scroll`, `shibarium`, `stability`, `suave`, `zetachain`, `zilliqa`, `zksync`

When CI adds or removes a chain type, update `scripts/chain-types.sh` and `index.ts`.

## Schemas merging

`scripts/merge-specs.mjs` merges all generated specs (public → private → chains alphabetically) into `openapi/merged.yaml`, which compiles to `dist/merged.schema.ts` (exported as `merged`).

Merge semantics:

- **Schemas** — `properties` are unioned; `required` is the intersection across specs defining a schema, so chain-specific properties are optional. Sub-objects defined in a single spec keep their `required` (e.g. `arbitrum.gas_used_for_l1` stays required when `arbitrum` is present). `enum` values are unioned (e.g. `transaction_types` gains chain-specific entries).
- **Paths & operations** — unioned across specs; chain-only endpoints (e.g. `/v2/arbitrum/batches`) are included. Shared operations are deep-merged, with `parameters` matched by (in, name) and their `schema`s unioned (e.g. enum query params gain chain-specific values). All operation `$ref`s point at `components.schemas`, so they reference the merged models automatically.
- Irreconcilable schema shapes (e.g. ethereum redefines `Status` as a beacon-deposit enum) become `anyOf` unions and are reported as warnings on stderr.