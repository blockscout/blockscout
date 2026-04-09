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

### Domain-scoped shared schemas

Domain subdirectories (e.g., `arbitrum/`, `optimism/`) can also contain leaf schemas shared across multiple schemas within that domain. This is the same pattern as `general/` primitives, but scoped to a specific chain or domain.

**When to extract:** When 2+ schemas in the same domain directory define an identical inline structure — either an object sub-schema with the same properties/types, or an enum with the same values. The trigger is duplication, not speculation: don't pre-extract a structure used by only one schema.

**Why it matters:**
- **For sub-objects** (e.g., a `commitment_transaction` block with 4 properties): if the structure changes, every inline copy must be found and updated. A shared schema eliminates this drift risk.
- **For enums** (e.g., a `batch_data_container` enum): each inline copy needs its own "keep in sync with Ecto" comment (see "Required: Ecto.Enum sync comments" below). A shared enum schema consolidates that comment to one location — the leaf module — so there's one place to update when Ecto enum values change.

**Where to put them:** In the domain subdirectory alongside the schemas that use them: `arbitrum/commitment_transaction.ex`, `arbitrum/batch_data_container.ex`.

**Template — shared object sub-schema:**

```elixir
defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.CommitmentTransaction do
  @moduledoc """
  Parent chain transaction that committed a batch.

  Shared across Batch and BatchForList schemas.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Parent chain transaction that committed the batch.",
    type: :object,
    properties: %{
      hash: General.FullHashNullable,
      block_number: %Schema{type: :integer, minimum: 0, nullable: true},
      timestamp: General.TimestampNullable,
      status: %Schema{type: :string, nullable: true, description: "Finalization status."}
    },
    required: [:hash, :block_number, :timestamp, :status],
    additionalProperties: false
  })
end
```

Then reference it in both schemas:

```elixir
# In Batch and BatchForList:
commitment_transaction: Arbitrum.CommitmentTransaction
```

**Template — shared enum leaf schema:**

```elixir
defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.BatchDataContainer do
  @moduledoc """
  Data availability container type for Arbitrum batches.
  """
  require OpenApiSpex

  # Enum values must be kept in sync with Explorer.Chain.Arbitrum.L1Batch :batch_container field.
  OpenApiSpex.schema(%{
    type: :string,
    enum: ["in_blob4844", "in_calldata", "in_celestia", "in_anytrust", "in_eigenda"],
    nullable: true,
    description: "Data availability container type."
  })
end
```

Then reference it in both schemas:

```elixir
batch_data_container: Arbitrum.BatchDataContainer
```

Note: the "keep in sync" comment lives in the leaf module. Schemas that reference it don't need their own copy — the single source of truth is the leaf module.

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

### Polymorphic properties (`oneOf`)

When a view branches on a discriminator field and emits different object shapes per branch, model the property using `oneOf`. Each variant is a standalone `%Schema{type: :object}` with its own properties and `additionalProperties: false`. The discriminator field (the field the view branches on) must appear in every variant so validation can match exactly one.

**Existing precedent:** `transaction.ex` uses `oneOf` for the `revert_reason` property (line ~392), which can be either a decoded input object or a raw hex string wrapper.

**Structural pattern:**

```elixir
polymorphic_field: %Schema{
  oneOf: [
    %Schema{
      type: :object,
      properties: %{discriminator: DiscriminatorType, field_a: ...},
      required: [:discriminator, :field_a],
      additionalProperties: false
    },
    %Schema{
      type: :object,
      properties: %{discriminator: DiscriminatorType, field_b: ..., field_c: ...},
      required: [:discriminator, :field_b, :field_c],
      additionalProperties: false
    }
  ],
  description: "Structure varies by `discriminator` value."
}
```

**Notes:**
- `discriminator:` (the OpenAPI 3.0 keyword) is optional in OpenApiSpex — the `oneOf` alone is sufficient for validation. OpenApiSpex checks each variant and requires exactly one to match.
- Each variant gets `additionalProperties: false`, which means test-time validation will catch extra or missing keys per variant — not just on the top-level schema.
- For simple variants (1-2 properties beyond the discriminator), inline schemas inside the `oneOf` list are fine. For larger or reusable variants, extract each into a domain schema module.

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

### Schema reuse and naming for related schemas

When multiple endpoints render the same underlying entity with different levels of detail (e.g., a list endpoint emits 7 fields while a main-page widget emits only 4), avoid duplicating properties across standalone schemas. Instead, use `extend_schema` to build one from the other.

**When to apply:** This is a post-factum decision — evaluate only when you're creating a new schema and discover an existing one in the same domain with overlapping properties. Don't speculatively refactor schemas that have only one consumer.

**Identifying the relationship:**
1. Compare the property sets of the existing and new schemas.
2. Determine which is the subset (fewer properties) and which is the superset.
3. Cross-reference with the Ecto schema to see which OpenAPI schema most closely matches the full entity.

**Naming convention:**
- The schema whose properties most closely match the Ecto schema should be named after the entity: `<Entity>` (e.g., `Message`). This is the "full" representation.
- The schema with fewer properties (a subset) should be named `Minimal<Entity>` (e.g., `MinimalMessage`). This clearly communicates it's a reduced view without tying the name to a specific endpoint.
- `extend_schema` only adds properties — it cannot subtract. So `Minimal<Entity>` is always the base that `<Entity>` extends.

**Renaming existing schemas:** If an existing schema was named for its endpoint (e.g., `MessageForMainPage`) and turns out to be the minimal subset, rename it to `Minimal<Entity>`. Update all references in controller operations, tests, and any other schemas that use it. Then create the full `<Entity>` schema extending it.

**Critical: always pass `title:` when extending.** Without an explicit `title:`, the child schema inherits the parent's auto-generated title. OpenApiSpex uses titles as keys in its internal schema registry, so two schemas with the same title collide — the child silently overwrites the parent. This causes test failures on the parent's endpoints because the wrong schema (with extra required fields) is used for validation.

**Template:**

```elixir
defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.Message do
  @moduledoc """
  Full Arbitrum cross-chain message schema.

  Extends `MinimalMessage` with: id, origination_address_hash, status.
  """

  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Arbitrum.MinimalMessage
  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    MinimalMessage.schema()
    |> Helper.extend_schema(
      title: "Arbitrum.Message",           # REQUIRED — prevents registry collision
      description: "Full Arbitrum cross-chain message.",
      properties: %{
        id: %Schema{type: :integer, minimum: 0},
        origination_address_hash: General.AddressHashNullable,
        status: %Schema{type: :string, enum: ["initiated", "sent", "confirmed", "relayed"]}
      },
      required: [:id, :origination_address_hash, :status]
    )
  )
end
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

### Required: Ecto.Enum sync comments

**Every `enum:` property in an OpenAPI schema must have a comment pointing to the source Ecto field.** There is no automatic sync between Ecto enums and OpenAPI enums — if someone adds a new value to the Ecto enum without updating the OpenAPI schema, `CastAndValidate` will reject the new value on input, and test-time validation will fail on output only if a test exercises that specific value. The comment is the only signal that tells the next developer where to look.

Format:
```elixir
# Enum values must be kept in sync with Explorer.Chain.<Module> :<field_name> field.
```

When using a shared enum leaf schema (see "Domain-scoped shared schemas" above), the comment lives in the leaf module only — schemas that reference it don't need their own copy. When using an inline enum, the comment goes directly above the `%Schema{type: :string, enum: [...]}` definition.

Before writing an inline enum, check existing schemas in the same domain — if another schema already defines the same enum, extract it into a shared leaf schema instead of duplicating it (and the comment).

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

### Nullable fields

If the Ecto schema field can be `nil` (not in `@required_attrs`, or the view conditionally emits it), the OpenAPI property should have `nullable: true`. If the key is always present but sometimes null, keep it in `required:` and set `nullable: true`. If the key is sometimes absent entirely, remove it from `required:`.

## Examples in schemas

Three patterns exist, all optional:

1. **Inline on a property**: `field: %Schema{type: :string, example: "transfer"}`
2. **Top-level on schema**: `example: %{field_a: "value", field_b: 42}`
3. **`next_page_params_example`**: passed to `paginated_response/1` for unstructured paging objects

Convention: use examples when the type is generic and readers need real-value context. Don't add examples to leaf pattern-based schemas (`FullHash`, `AddressHash`, etc.) — their type and pattern are self-documenting.
