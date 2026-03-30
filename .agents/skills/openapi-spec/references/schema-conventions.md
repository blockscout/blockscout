# Schema Conventions

All schema modules live under `apps/block_scout_web/lib/block_scout_web/schemas/api/v2/`.

## Directory structure conventions

These conventions are inferred from consistent patterns — there's no written doc.

### Base entity + subdirectory pattern

Major domain objects have a base file at the root plus a same-named subdirectory for sub-schemas:

```
schemas/api/v2/
  transaction.ex          # base Transaction schema (properties, types)
  transaction/
    response.ex           # Transaction.Response (extends base with title/description)
    fee.ex                # Transaction.Fee
    counters.ex           # Transaction.Counters
    state_change.ex       # Transaction.StateChange
```

This pattern applies to: `address`, `block`, `blob`, `token`, `transaction`, `withdrawal`, `smart_contract`, and chain-specific domains (`optimism/batch`, `celo/election_reward`, etc.).

### When to create a subdirectory

Create a subdirectory when 2+ sub-schemas exist for a domain entity. Simple leaf entities (`CoinBalance`, `Log`, `InternalTransaction`) have no subdirectory — just a single file.

### Shared primitives in `general/`

`general/` contains ~22 reusable type schemas: `AddressHash`, `FullHash`, `IntegerString`, `Timestamp`, nullable variants, etc. These are leaf schemas referenced by property types across all domain schemas.

To discover available primitives, glob `schemas/api/v2/general/*.ex`.

### Chain-specific schemas

Chain-specific schemas get top-level subdirectories: `optimism/`, `scroll/`, `celo/`, `zilliqa/`, `beacon/`. These map to chain-conditional router scopes.

### File naming

Snake_case files, CamelCase modules: `transaction/fee.ex` contains `BlockScoutWeb.Schemas.API.V2.Transaction.Fee`.

## Schema composition patterns

### Leaf schemas (primitives)

Single-purpose modules — one-liner `OpenApiSpex.schema/1` calls:

```elixir
# general/full_hash.ex
defmodule BlockScoutWeb.Schemas.API.V2.General.FullHash do
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{type: :string, pattern: General.full_hash_pattern(), nullable: false})
end
```

### Composite object schemas

Larger schemas with `type: :object`:

```elixir
OpenApiSpex.schema(%{
  title: "TransactionFee",
  description: "Transaction fee details",
  type: :object,
  required: [:type, :value],
  properties: %{
    type: %Schema{type: :string, enum: ["maximum", "actual"]},
    value: General.IntegerStringNullable
  },
  additionalProperties: false    # always set this on object schemas
})
```

Key conventions:
- **`additionalProperties: false`** — always set on object schemas. This enables test-time enforcement: any key the view emits that isn't in the schema causes a test failure.
- **`required:`** — list all keys that the view always emits.
- **Property values** can be schema modules (like `General.IntegerStringNullable`) or inline `%Schema{}` structs.

### Response schemas

Response schemas extend a base entity schema with title/description:

```elixir
# transaction/response.ex
OpenApiSpex.schema(
  Transaction.schema()
  |> Helper.extend_schema(
    title: "TransactionResponse",
    description: "Transaction response"
  )
  |> ChainTypeCustomizations.chain_type_fields()
)
```

The pattern is: base schema -> extend with metadata -> apply chain-type fields.

### Helper.extend_schema/2

Located at `schemas/helper.ex`. Merges `:properties`, `:required`, `:title`, `:description`, `:nullable`, and `:enum` into an existing schema map:
- Properties are merged (new keys added, existing overwritten)
- Required lists are concatenated
- Scalar fields (title, description, nullable) are replaced

```elixir
schema_map
|> Helper.extend_schema(
  title: "ExtendedSchema",
  properties: %{new_field: %Schema{type: :string}},
  required: [:new_field]
)
```

### Paginated response wrapper

For list endpoints, use `General.paginated_response/1`:

```elixir
# In the operation macro
responses: [
  ok: {"Token transfer list", "application/json",
       paginated_response(
         items: Schemas.TokenTransfer,
         next_page_params_example: %{"index" => 442, "block_number" => 21307214}
       )}
]
```

This wraps the item schema in a standard envelope:
```json
{"items": [...], "next_page_params": {...} | null}
```

The `next_page_params` is typed as a generic `type: :object, nullable: true` with no fixed properties — only the `example` documents expected keys.

## Chain-type customization pattern

Schemas and views use the same dispatch mechanism for chain-specific fields:

```elixir
# In a ChainTypeCustomizations module (co-located in the parent schema file)
def chain_type_fields(schema) do
  case chain_type() do
    :zksync   -> schema |> Helper.extend_schema(properties: %{zksync: @zksync_schema})
    :arbitrum  -> schema |> Helper.extend_schema(properties: %{arbitrum: @arbitrum_schema})
    :optimism  -> schema |> Helper.extend_schema(properties: %{l1_fee: ...})
    _          -> schema
  end
end
```

ChainTypeCustomizations modules are almost always defined at the top of the same `.ex` file as the schema they modify. One exception: `general/implementation/chain_type_customizations.ex`.

When creating a new schema that needs chain-type support:
1. Define the base schema with default-chain properties
2. Add a `ChainTypeCustomizations` module in the same file
3. Pipe the schema through `ChainTypeCustomizations.chain_type_fields/1`

## Creating a new schema module

### Template for a new object schema

```elixir
defmodule BlockScoutWeb.Schemas.API.V2.MyDomain do
  alias OpenApiSpex.Schema
  alias BlockScoutWeb.Schemas.API.V2.General

  require OpenApiSpex

  @moduledoc "Schema for MyDomain entity"

  OpenApiSpex.schema(%{
    title: "MyDomain",
    description: "Description of this entity",
    type: :object,
    required: [:field_a, :field_b],
    properties: %{
      field_a: %Schema{type: :string, description: "What field_a is"},
      field_b: General.IntegerString,
      field_c: %Schema{type: :string, nullable: true}
    },
    additionalProperties: false
  })
end
```

### Template for a response wrapper

```elixir
defmodule BlockScoutWeb.Schemas.API.V2.MyDomain.Response do
  alias BlockScoutWeb.Schemas.API.V2.MyDomain
  alias BlockScoutWeb.Schemas.Helper

  require OpenApiSpex

  OpenApiSpex.schema(
    MyDomain.schema()
    |> Helper.extend_schema(
      title: "MyDomainResponse",
      description: "MyDomain response"
    )
  )
end
```

### Aliasing in controllers

The `block_scout_web.ex` `:controller` block provides:
```elixir
alias BlockScoutWeb.Schemas.API.V2, as: Schemas
```

So in controllers you reference schemas as `Schemas.MyDomain.Response`.

## Determining property types from Ecto schemas

The view layer is lossy about types — it renders everything as JSON primitives. To declare precise OpenAPI types, cross-reference with the underlying Ecto schema in the Explorer app (`apps/explorer/lib/explorer/chain/<domain>.ex`).

### Discovery process

1. Identify the Ecto schema module for the entity. The view's `prepare_*` function usually receives a struct — trace its type back to the `Explorer.Chain.*` module.
2. Read the Ecto schema's `schema` block and `@type` definition to see the field types.
3. Grep for `Ecto.Enum` in the file to find enum fields.

### Ecto type → OpenAPI type mapping

| Ecto type | OpenAPI schema | Notes |
|---|---|---|
| `Ecto.Enum` with values | `%Schema{type: :string, enum: [...values...]}` | Extract the atom values list from the Ecto schema. Convert atoms to strings for the enum. |
| `:string` | `%Schema{type: :string}` | |
| `:integer` | `%Schema{type: :integer}` | If the view converts large integers to strings (common for Wei values), use `IntegerString` instead |
| `:boolean` | `%Schema{type: :boolean}` | |
| `:decimal` | `%Schema{type: :string}` or `FloatString` | Decimals are typically serialized as strings to preserve precision |
| `Explorer.Chain.Hash.Full` | `General.FullHash` | 0x + 64 hex chars |
| `Explorer.Chain.Hash.Address` | `General.AddressHash` | 0x + 40 hex chars |
| `:utc_datetime_usec` | `General.Timestamp` or `General.TimestampNullable` | ISO 8601 datetime string |
| `:map` | `%Schema{type: :object}` | Check what keys the view actually emits |
| `{:array, inner_type}` | `%Schema{type: :array, items: ...}` | Map the inner type recursively |

### Ecto.Enum example

If the Ecto schema has:
```elixir
field(:batch_data_container, Ecto.Enum, values: [:in_blob4844, :in_calldata, :in_celestia])
```

The OpenAPI property should be:
```elixir
# Enum values must be kept in sync with Explorer.Chain.Arbitrum.L1Batch :batch_data_container field.
batch_data_container: %Schema{
  type: :string,
  enum: ["in_blob4844", "in_calldata", "in_celestia"],
  nullable: true    # if the field can be nil
}
```

Enum values are duplicated between the Ecto schema and the OpenAPI schema — there is no automatic sync. If someone adds a new value to the Ecto enum without updating the OpenAPI schema, `CastAndValidate` will reject the new value on input, and test-time validation will fail on output only if a test exercises that specific value. To mitigate this, always add a code comment on the enum property pointing to the source Ecto field, e.g.:
```elixir
# Enum values must be kept in sync with Explorer.Chain.<Module> :<field_name> field.
```

Check existing schemas in the same domain for precedent — similar entities often already use enum for the same kind of field, and you should follow the same pattern.

### Nullable fields

If the Ecto schema field can be `nil` (not in `@required_attrs`, or the view conditionally emits it), the OpenAPI property should have `nullable: true`. If the key is always present but sometimes null, keep it in `required:` and set `nullable: true`. If the key is sometimes absent entirely, remove it from `required:`.

## Examples in schemas

Three patterns exist, all optional:

1. **Inline on a property**: `field: %Schema{type: :string, example: "transfer"}`
2. **Top-level on schema**: `example: %{field_a: "value", field_b: 42}`
3. **`next_page_params_example`**: passed to `paginated_response/1` for unstructured paging objects

Convention: use examples when the type is generic and readers need real-value context. Don't add examples to leaf pattern-based schemas (`FullHash`, `AddressHash`, etc.) — their type and pattern are self-documenting.
