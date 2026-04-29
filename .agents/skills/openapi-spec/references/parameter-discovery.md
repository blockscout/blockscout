# Parameter Discovery Guide

All parameter helper functions are centralized in a single file:
`apps/block_scout_web/lib/block_scout_web/schemas/api/v2/general.ex`

They are auto-imported into every controller via `block_scout_web.ex`:
```elixir
import BlockScoutWeb.Schemas.API.V2.General
```

No controllers or other schema modules define their own parameter helpers — `general.ex` is the single source.

## How to discover existing helpers

### Find a specific helper

Grep for the function name in `general.ex`:
```
grep "def transaction_hash_param" in general.ex
```

Parameter helpers follow the naming convention `<descriptive_name>_param` for single params, and `<name>_params` for grouped helpers.

### Browse all helpers

Grep for `def.*_param` in `general.ex` to see the full list. There are ~48 helpers organized into functional categories (described below).

To see which parameter names actually reach the generated spec, run recipe K in `references/oastools-audit-recipes.md`. The spec surfaces ~92 distinct names — diff against `general.ex` to find zombie helpers (defined but never used) and inline-only names (declared in controllers, candidates for promotion to `general.ex`).

### Find which controllers use a helper

Grep for the function name across `controllers/api/v2/`:
```
grep "transaction_hash_param()" in controllers/api/v2/**/*.ex
```

`oastools walk parameters -name <helper_name> -q .ai/tmp/openapi_public.yaml` (recipe J) is authoritative about which endpoints *declare* the parameter in the spec — it doesn't see controller-private helpers or inline `%Parameter{}` structs, but it won't miss anything wired into the public spec.

## Naming conventions

| Category | Naming pattern | Examples |
|---|---|---|
| Path identifiers | `<entity>_hash_param`, `<entity>_number_param`, `<entity>_id_param` | `address_hash_param`, `block_number_param`, `token_id_param` |
| Domain filters | `<what_it_filters>_param` | `token_type_param`, `direction_filter_param`, `transaction_filter_param` |
| Sorting | `sort_param(fields)`, `order_param` | `sort_param(["name", "holder_count"])` |
| Boolean toggles | descriptive name | `just_request_body_param` |
| Authentication | `<purpose>_param` | `api_key_param`, `key_param`, `admin_api_key_param` |
| Paging factories | `define_paging_params(field_names)` | `define_paging_params(["index", "block_number"])` |

## Functional categories

When looking for existing helpers, think about which category the parameter falls into:

**A. Path identifiers** — Entity identifiers in URL path segments. Grep: `def.*_hash_param\|def.*_number_param\|def.*_id_param`.

**B. Domain filters** — Query params that filter list results. Grep: `def.*_filter_param\|def.*_type_param\|def.*q_param`.

**C. Sorting** — `sort_param/1` takes a list of allowed sort fields, `order_param/0` provides asc/desc. Grep: `def sort_param\|def order_param`.

**D. Paging factories** — `define_paging_params/1` generates multiple `%Parameter{in: :query}` structs from a list of field name strings. There are also `define_state_changes_paging_params/1` and `define_search_paging_params/1` variants. Grep: `def define_paging_params\|def define.*paging`.

**E. Authentication** — `api_key_param`, `key_param` (bundled as `base_params()`), `admin_api_key_param` (header), `recaptcha_response_param`. Grep: `def.*api_key\|def.*key_param\|def recaptcha`.

**F. Composite helpers** — `base_params()` returns `[api_key_param(), key_param()]`. Grep: `def base_params`.

## Creating a new parameter helper

### When to create a helper vs inline

- **Create a helper in `general.ex`** if the parameter is a generic concept reusable across multiple controllers (entity hashes, block numbers, token types).
- **Create a private helper in the controller** if the parameter is domain-specific but used by multiple operations in the same controller (e.g., an Arbitrum message direction param shared by `messages` and `messages_count`). This avoids polluting `general.ex` with chain-specific concerns while preventing copy-paste duplication across operations.
- **Use inline `%Parameter{}`** only if the parameter is truly unique to a single operation.

### Helper function template

```elixir
@spec my_new_param() :: Parameter.t()
def my_new_param do
  %Parameter{
    name: :my_new_param,       # atom — must match route segment and controller pattern-match
    in: :path,                  # :path | :query | :header
    schema: FullHash,           # a schema module or inline %Schema{}
    required: true,             # true for path params, typically false for query params
    description: "Description of what this parameter does"
  }
end
```

Place it in `general.ex` near other helpers of the same category. The file is organized roughly by category, though not strictly enforced.

### Inline parameter template

For one-off parameters, define directly in the `operation` macro arguments:

```elixir
operation :my_action,
  parameters: [
    %OpenApiSpex.Parameter{
      name: :height,
      in: :path,
      schema: Schemas.General.IntegerString,
      required: true,
      description: "Block height"
    }
    | base_params()
  ],
  responses: [...]
```

## Schema types for parameters

Parameter schemas reference leaf schema modules from `schemas/api/v2/general/`:

| Type | Module | Use for |
|---|---|---|
| Full hash (0x + 64 hex) | `FullHash` | Transaction hashes, block hashes |
| Address hash (0x + 40 hex) | `AddressHash` | Address identifiers |
| Integer as string | `IntegerString` | Numeric IDs passed as strings |
| Hex string | `HexString` | Arbitrary hex data |
| Generic string | `%Schema{type: :string}` | Free-form text, API keys |
| Boolean | `%Schema{type: :boolean}` | Toggle flags |
| Enum | `%Schema{type: :string, enum: [...]}` | Fixed set of allowed values |

To discover available leaf schemas, glob `schemas/api/v2/general/*.ex`.

## The `define_paging_params` factory

For paginated list endpoints, pagination cursor parameters are generated from a list of field names:

```elixir
define_paging_params(["index", "block_number", "batch_log_index"])
```

This creates one `%Parameter{in: :query, required: false}` per field name. The string names are converted to atoms as the parameter `:name`. Each gets an `IntegerString` schema by default.

**Always include `"items_count"`** in the field list. The `next_page_params/5` function in `chain.ex` unconditionally adds `items_count` to every pagination cursor. If the operation doesn't declare it as a query param, CastAndValidate will reject next-page requests with "Unexpected field: items_count." Example: `define_paging_params(["id", "items_count"])`.

There are specialized variants:
- `define_state_changes_paging_params/1` — for state change pagination
- `define_search_paging_params/1` — for search result pagination (uses object params)

Grep `define_paging_params\|define_state_changes\|define_search` in `general.ex` to see their implementations.
