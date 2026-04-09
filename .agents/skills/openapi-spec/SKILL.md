---
name: openapi-spec
description: "Create, adjust, or inspect OpenAPI declarations for Blockscout API v2 endpoints. Use this skill whenever the user asks to: add an OpenAPI spec to an endpoint that lacks one, update a spec after controller/view changes, audit or fix an existing OpenAPI declaration, or work with open_api_spex annotations in the Blockscout codebase. Also trigger when the user mentions 'swagger', 'openapi', 'open_api_spex', 'API spec', 'API schema', or 'operation macro' in the context of Blockscout endpoints."
---

# OpenAPI Spec Authoring for Blockscout API v2

This skill covers three workflows for Blockscout's OpenAPI declarations:
- **Create** — add a declaration for an endpoint that has none
- **Adjust** — update a declaration after parameters or response changed
- **Inspect & Fix** — audit an existing declaration for correctness issues

Blockscout uses the `open_api_spex` library (v3.22+) to define OpenAPI 3.0 specs inline in Elixir code. There are no hand-written spec files — the spec is derived entirely from annotations in controllers and schema modules, then assembled at runtime via router introspection.

## Key file locations

All paths are relative to `apps/block_scout_web/lib/block_scout_web/`:

| What | Where |
|---|---|
| Controllers | `controllers/api/v2/<domain>_controller.ex` |
| Account controllers | `controllers/account/api/v2/<domain>_controller.ex` |
| Schema modules | `schemas/api/v2/<domain>.ex` and `schemas/api/v2/<domain>/*.ex` |
| Parameter helpers | `schemas/api/v2/general.ex` (all helpers centralized here) |
| Error responses | `schemas/api/v2/error_responses.ex` |
| Schema helper | `schemas/helper.ex` (`extend_schema/2`) |
| Leaf type schemas | `schemas/api/v2/general/*.ex` (AddressHash, FullHash, IntegerString, etc.) |
| API router | `routers/api_router.ex` |
| Sub-routers | `routers/tokens_api_v2_router.ex`, `routers/smart_contracts_api_v2_router.ex` |
| Account router | `routers/account_router.ex` |
| Views | `views/api/v2/<domain>_view.ex` |
| Paging helper | `paging_helper.ex` (`delete_parameters_from_next_page_params/1`) |
| Spec aggregators | `specs/public.ex`, `specs/private.ex` |
| Global aliases/imports | The file `block_scout_web.ex` — look for `:controller` quote block |
| Tests | `../../test/block_scout_web/controllers/api/v2/<domain>_controller_test.exs` |

## Core patterns

### The operation macro

Every annotated controller action has an `operation/2` call (from `OpenApiSpex.ControllerSpecs`):

```elixir
operation :action_name,
  summary: "Short summary for the endpoint",
  description: "Longer description of what it does.",
  parameters: [some_path_param() | base_params()],
  responses: [
    ok: {"Success description", "application/json", Schemas.SomeDomain.Response},
    not_found: NotFoundResponse.response(),
    unprocessable_entity: JsonErrorResponse.response()
  ]
```

For POST/PUT/PATCH endpoints, add `request_body:` — see `references/request-body-security-headers.md`.

### The three-way parameter coupling

Path parameters must be consistent across three locations or the endpoint breaks:

| Location | Form | Example |
|---|---|---|
| Phoenix route segment | String with `:` prefix | `get("/:transaction_hash_param", ...)` |
| `%Parameter{}` struct | Atom in `:name` field | `%Parameter{name: :transaction_hash_param, in: :path}` |
| Controller action head | Atom key in pattern match | `def transaction(conn, %{transaction_hash_param: value})` |

`CastAndValidate` reads string keys from `conn.path_params`, converts them to atoms using the Parameter `:name`, and places them in `conn.params`. The controller then pattern-matches on those atoms.

### Response schema ↔ view correlation

There is no runtime validation that view output matches the response schema. Alignment is enforced **only at test time**: every `json_response/2` call in a `ConnCase` test automatically validates the response body against the OpenAPI spec. This means:
- Schemas with `additionalProperties: false` catch extra keys the view emits
- The `required` list catches missing keys
- Type/pattern checks catch type mismatches

If a view emits a key not in the schema (or vice versa), tests will fail.

### CastAndValidate's effect on params (string keys → atom keys)

When `CastAndValidate` processes an action with a real `operation` spec (not `operation :action, false`), it transforms **all** params before the action runs:
- **String keys become atom keys:** `%{"id" => "42"}` → `%{id: 42}`
- **Values are cast to declared types:** strings become integers, booleans, etc., based on the parameter's `%Schema{type: ...}`

Actions declared with `operation :action, false` are **skipped** — they receive the original string-keyed params from Phoenix unchanged.

This matters most for **pagination**. The `paging_options/1` function in `chain.ex` has parallel clauses for both forms:
- String-key clauses (e.g., `%{"id" => id_string} when is_binary(id_string)`) — used by actions without a spec
- Atom-key clauses (e.g., `%{id: id}`) — used by actions with a real spec

When promoting an action from `operation :action, false` to a real spec, the string-key `paging_options` clause will stop matching. You must ensure a corresponding atom-key clause exists. See Workflow A, Step 4b for details.

### base_params() — always include

`base_params()` returns `[api_key_param(), key_param()]` — two optional query parameters (`apikey`, `key`) present on every public API operation. Always include it.

Common composition patterns:
```elixir
# Simple — no extra params
parameters: base_params()

# With a path param (prepend via cons)
parameters: [address_hash_param() | base_params()]

# With paging params (append via ++)
parameters: base_params() ++ define_paging_params(["index", "block_number"])

# Combined
parameters: [transaction_hash_param() | base_params()] ++ [token_type_param()] ++ define_paging_params(["index", "block_number"])
```

### Controller prerequisites

Every annotated controller needs:
```elixir
use OpenApiSpex.ControllerSpecs                          # injects operation/2, tags/1
plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)  # validates incoming params
tags(["domain-tag"])                                      # groups operations in spec
```

These are typically near the top of the controller module, after `use BlockScoutWeb, :controller`.

---

## Verification

After creating or modifying a declaration, verify it using these methods in order. Each catches a different class of issues, and earlier steps are faster — so run them first to get quick feedback before committing to a full test run.

### 1. Compile (`mix compile`)

Compiling the `block_scout_web` app verifies structural validity: schema modules exist, operation names match controller action function names, and all referenced modules resolve. This is the fastest check and catches typos, missing modules, and wiring errors.

Run via devcontainer if mix is not available on the host.

### 2. Generate the spec (`mix openapi.spec.yaml`)

This exercises `OpenApiSpex.resolve_schema_modules/1`, which resolves all schema module references and inlines them into the full spec. It catches issues that compilation alone misses: circular references, malformed schema structures, and resolution failures.

```bash
mix openapi.spec.yaml --spec BlockScoutWeb.Specs.Public /tmp/openapi_check.yaml --start-app=false
```

For chain-specific endpoints, set `CHAIN_TYPE`:
```bash
CHAIN_TYPE=optimism mix openapi.spec.yaml --spec BlockScoutWeb.Specs.Public /tmp/openapi_check.yaml --start-app=false
```

The generated YAML can also be visually inspected or fed to external OpenAPI validators for additional checks.

### 3. Run controller tests (`mix test`)

Run the specific controller test file. Every `json_response/2` call automatically validates the response body against the OpenAPI schema. This catches response-level issues: extra keys (via `additionalProperties: false`), missing required keys, and type mismatches.

```bash
mix test apps/block_scout_web/test/block_scout_web/controllers/api/v2/<domain>_controller_test.exs
```

If tests fail with schema validation errors, the view output doesn't match the declared schema — fix the discrepancy.

### 4. Code cross-referencing (for Inspect & Fix workflow)

Manually or via grep, compare the controller's consumed parameters against declared parameters, and the view's output keys against schema properties. This catches logical issues that tests might miss (e.g., an undeclared optional parameter that works at runtime but isn't documented, or a schema property that's declared but never emitted by the view).

See `references/inspection-checklist.md` for the systematic approach.

---

## Workflow A: Create a new declaration

Use this when an endpoint exists (route + controller action + view) but has no `operation/2` annotation.

### Step 1: Gather context

Read these files in parallel to understand the endpoint:

1. **Router** — find the route definition. Note the HTTP method, path segments (especially `:param_name` segments), and which controller/action it maps to.
2. **Controller** — read the action function. Note what keys it destructures from `params` and `conn.body_params`, what data it fetches, and what view template it renders.
3. **View** — read the render function and any `prepare_*` helper it calls. Note every key in the output map — these become schema properties. Trace **all code paths**, not just the default: look for `case`/`cond`/pattern-match branches in the render function and its helpers that produce different map shapes depending on a field value. When found, note the discriminator field and the distinct set of keys each branch emits — these indicate a polymorphic sub-object that needs special handling in Step 3.
4. **Existing schemas** — glob `schemas/api/v2/<domain>*` to see if schema modules already exist for this domain.

### Step 2: Find or create parameter definitions

For each parameter the controller reads:

1. **Check if a helper already exists.** Grep `general.ex` for a function matching the parameter name:
   ```
   # For a path param named :address_hash_param
   grep "def address_hash_param" in general.ex
   ```
   Read `references/parameter-discovery.md` for naming conventions and discovery patterns.

2. **If no helper exists**, decide:
   - **Reusable across controllers?** Add a new helper function to `general.ex` following the naming conventions in `references/parameter-discovery.md`.
   - **One-off?** Define an inline `%OpenApiSpex.Parameter{}` struct directly in the `operation` macro arguments.

3. **For pagination parameters**, use `define_paging_params(field_names)` — pass the cursor field names as strings, and **always include `"items_count"`**. The `next_page_params` helper adds `items_count` to every paginated response automatically, so CastAndValidate must accept it as a query param. Example: `define_paging_params(["id", "items_count"])`.

### Step 3: Create or locate response schema

1. **Check if a schema module exists** for the response entity. Glob `schemas/api/v2/<domain>*.ex`.
2. **If schemas exist in the same domain**, compare their properties against the new view's output keys to detect subset/superset relationships:
   - **Existing schema is a subset** of what the new endpoint needs — use `extend_schema` from the existing schema, adding only the extra properties. See `references/schema-conventions.md` section "Schema reuse and naming for related schemas" for the naming convention and required `title:` parameter.
   - **Existing schema is a superset** — the new endpoint may reference the existing schema directly (if it needs all the properties), or may need a reduced "minimal" schema that the existing one extends.
   - **No meaningful overlap** — create a standalone schema.
3. **If no suitable schema exists**, create one following the conventions in `references/schema-conventions.md`. The schema's properties must match the view's output keys exactly.
4. **Deduplicate against existing domain schemas.** Before finalizing properties, compare each inline `%Schema{type: :object}` block and each `%Schema{type: :string, enum: [...]}` definition in the new schema against properties in the existing schemas found in step 1. If an identical structure already exists in another schema in the same domain directory, extract it into a shared leaf schema module and reference it from both schemas. This avoids drift when the structure changes and consolidates Ecto.Enum sync comments to one location. See `references/schema-conventions.md` section "Domain-scoped shared schemas" for templates.
5. **Model polymorphic sub-objects.** If Step 1 identified a property whose structure varies based on a discriminator field (e.g., a `data_availability` object that changes shape depending on `batch_data_container`), a single flat `%Schema{type: :object}` with only the common fields will be incomplete — the variant-specific fields won't be documented or validated. Use `oneOf` to declare each variant explicitly. Each variant is a `%Schema{type: :object}` with its own properties, `required` list, and `additionalProperties: false`. The discriminator field appears in every variant. If the view has a catch-all branch (e.g., `value -> %{"field" => to_string(value)}`), model it as the minimal variant containing only the discriminator. For existing precedent, see `transaction.ex` (`revert_reason` property). Template:
   ```elixir
   data_availability: %Schema{
     oneOf: [
       # Variant: nil / in_blob4844 / in_calldata (no extra fields)
       %Schema{
         type: :object,
         properties: %{batch_data_container: BatchDataContainer},
         required: [:batch_data_container],
         additionalProperties: false
       },
       # Variant: in_anytrust
       %Schema{
         type: :object,
         properties: %{
           batch_data_container: BatchDataContainer,
           data_hash: %Schema{type: :string, nullable: true},
           timeout: %Schema{type: :string, nullable: true},
           bls_signature: %Schema{type: :string, nullable: true},
           signers: %Schema{type: :array, items: %Schema{type: :string}}
         },
         required: [:batch_data_container, :data_hash, :timeout, :bls_signature, :signers],
         additionalProperties: false
       },
       # ... additional variants
     ],
     description: "Data availability info. Structure varies by `batch_data_container`."
   }
   ```
   For 2-3 simple variants, inline schemas inside the `oneOf` list are fine. For more variants or cross-schema reuse, extract each into a domain schema module. Note: `discriminator:` (the OpenAPI 3.0 keyword) is optional in OpenApiSpex — `oneOf` alone is sufficient for validation.
6. **Determine precise types from the Ecto schema.** The view renders everything as JSON primitives (strings, integers, etc.), but the underlying Ecto schema in the Explorer app knows the real constraints. Read the Ecto schema module for the entity (under `apps/explorer/lib/explorer/chain/`) and check for:
   - `Ecto.Enum` fields — these should become `%Schema{type: :string, enum: [...values...]}`, not just `type: :string`. Grep for `Ecto.Enum` in the Ecto schema to find them, and check the enum values defined there. **Every enum property requires a sync comment** — see `references/schema-conventions.md` section "Required: Ecto.Enum sync comments".
   - Nullable fields — if the Ecto schema allows `nil`, the OpenAPI property should have `nullable: true`.
   - Integer vs string — if the Ecto field is an integer type but the view converts it to a string (e.g., for large numbers), use an appropriate schema like `IntegerString`.
   See `references/schema-conventions.md` section "Determining property types from Ecto schemas" for more detail.
7. **Set `additionalProperties: false`** on object schemas — this is a project-wide convention that enables test-time enforcement.
   - **For non-negative integer properties** (block numbers, batch numbers, counts, indices, nonces), set `minimum: 0` to enforce the domain constraint at the validation level.
8. **Set `required:`** to list all keys that the view always emits.
9. For paginated list endpoints, use `General.paginated_response/1` to wrap the item schema.

### Step 4a: Write the operation annotation

Add the `operation/2` call above the controller action. Follow the structure in "The operation macro" section above. Make sure:
- `summary:` is a short imperative sentence
- `description:` adds useful detail beyond the summary
- `parameters:` includes `base_params()` and all path/query params
- `responses:` covers the success case and all error cases the action can return

If the controller lacks the `use OpenApiSpex.ControllerSpecs` line and `CastAndValidate` plug, add them (see "Controller prerequisites").

### Step 4b: Update paging_options if the endpoint is paginated

If the action calls `paging_options(params)` (directly or via helpers like `next_page_params`), the string-key clauses in `chain.ex` will no longer match because `CastAndValidate` has already converted params to atom keys with cast types.

Check `chain.ex` for the relevant `paging_options` clause. If only a string-key clause exists (e.g., `%{"id" => id_string}` with `Integer.parse`):
- **Add** a matching atom-key clause (e.g., `%{id: id}`) if the string-key clause is still used by other actions without specs
- **Replace** the string-key clause with an atom-key one if all callers now go through `CastAndValidate`

The atom-key clause is typically simpler because `CastAndValidate` already handles type casting — no `Integer.parse` or similar parsing needed.

This step is especially important when **promoting** an action from `operation :action, false` to a real spec — that is the moment where `paging_options` stops receiving string keys and the mismatch occurs.

### Step 4c: Ensure path params are excluded from `next_page_params`

If the endpoint is paginated **and** has path parameters, those path params will leak into the pagination cursor response unless explicitly stripped.

**Why this happens:** CastAndValidate converts all params (path + query) to atom keys in a single map. The `next_page_params/5` function receives this map and builds the cursor for the response. It calls `delete_parameters_from_next_page_params/1` (in `paging_helper.ex`) to strip known non-pagination params, but only params listed in its `Map.drop` list are removed. If a path param isn't listed, it appears in the JSON response's `next_page_params`. When the client sends that cursor back as query params on the next request, CastAndValidate rejects the path param as "Unexpected field" because it's declared as `:path`, not `:query`.

**What to do:** For each path parameter declared in the operation:
1. Read `delete_parameters_from_next_page_params/1` in `apps/block_scout_web/lib/block_scout_web/paging_helper.ex`.
2. Check whether the atom-key form (e.g., `:direction`) is in the `Map.drop` list.
3. If missing, add it among the other atom-key entries at the top of the list.

The existing list already includes common path params like `:address_hash_param`, `:batch_number_param`, `:block_hash_or_number_param`, `:transaction_hash_param`. New path params need to be added as they are introduced.

### Step 5: Ensure test coverage

Tests are the primary mechanism that validates the response schema matches the actual view output. Without tests hitting the endpoint, the schema is unverified documentation that may be wrong.

1. **Check if tests already exist.** Look for the test file at `apps/block_scout_web/test/block_scout_web/controllers/api/v2/<domain>_controller_test.exs`. Grep for the endpoint path or action name within the file.

2. **If tests exist** that hit this endpoint and call `json_response/2`, they will automatically validate the schema. Proceed to Step 6.

3. **If no tests exist** for this endpoint, create them. At minimum, write tests for the following cases:

```elixir
# For a list endpoint — empty response, zero factory data needed
test "empty list", %{conn: conn} do
  request = get(conn, "/api/v2/<path>")
  assert response = json_response(request, 200)
  assert response["items"] == []
  assert response["next_page_params"] == nil
end

# For a single-resource endpoint
test "returns resource", %{conn: conn} do
  resource = insert(:<factory_name>)
  request = get(conn, "/api/v2/<path>/#{resource.id}")
  assert _response = json_response(request, 200)
end

# Not-found case (build without inserting)
test "returns 404 for non-existing resource", %{conn: conn} do
  resource = build(:<factory_name>)
  request = get(conn, "/api/v2/<path>/#{resource.id}")
  assert %{"message" => "Not found"} = json_response(request, 404)
end

# Validation error (invalid parameter value)
test "returns 422 on invalid input", %{conn: conn} do
  request = get(conn, "/api/v2/<path>/invalid_value")
  assert %{"errors" => [_]} = json_response(request, 422)
end
```

Choose the templates that match the endpoint type (list vs single resource). The `json_response/2` call is what triggers schema validation — every test that calls it automatically verifies the response against the declared OpenAPI schema.

4. **If the schema contains `oneOf` polymorphic sub-objects** (from Step 3 item 5), write at least one test per variant so that each branch's `additionalProperties: false` constraint is exercised. The default factory typically produces only the simplest variant (e.g., a nil discriminator), so tests for other variants need explicit setup — insert the factory with the discriminator value set, plus any associated records the view fetches for that branch.

### Step 6: Verify

Run through the verification ladder described in the "Verification" section above:

1. **Compile** — confirm the new schema modules and operation annotation are structurally valid.
2. **Generate the spec** — confirm the spec resolves cleanly with the new declaration included.
3. **Run tests** — run the tests from Step 5. If schema validation errors occur, the view output doesn't match the declared schema — fix the discrepancy.

---

## Workflow B: Adjust an existing declaration

Use this when an endpoint's parameters or response have changed and the OpenAPI spec needs to catch up.

### Step 1: Identify the change

Read the controller action and view to understand what changed. Common scenarios:
- **New parameter added** — controller now reads a new key from params
- **Parameter removed** — controller no longer uses a parameter
- **New response field** — view now emits an additional key
- **Response field removed** — view no longer emits a key
- **Type changed** — a field's type or format changed

### Step 2: Update the declaration

- **Parameters**: Add/remove from the `parameters:` list in the `operation` macro. If adding a new reusable param, add a helper to `general.ex`.
- **Response fields**: Update the schema module's `properties:` map and `required:` list. If adding a field, add it to both. If removing, remove from both.
- **Type changes**: Update the property's schema type in the schema module.

### Step 3: Verify

Run through the verification ladder described in the "Verification" section above:

1. **Compile** — confirm the modified schema modules still resolve.
2. **Generate the spec** — confirm the spec is still valid after changes.
3. **Run tests** — confirm updated response schemas match the view output.

---

## Workflow C: Inspect & fix an existing declaration

Use this to audit an existing declaration for correctness, completeness, and adherence to project conventions.

Read `references/inspection-checklist.md` for the full systematic checklist. The high-level steps:

1. **Code cross-referencing** — verify parameter completeness (controller reads vs declared params), response field alignment (view output vs schema properties), three-way coupling consistency, and convention compliance.
2. **Compile** — confirm no structural issues after any fixes applied.
3. **Generate the spec** — confirm the full spec resolves cleanly.
4. **Run tests** — confirm response schemas match view output. Check that tests exist for key status codes (200, 404, 422).

---

## When to read reference files

| Reference | Read when... |
|---|---|
| `references/parameter-discovery.md` | You need to find existing parameter helpers, create new ones, or understand naming/categorization conventions |
| `references/schema-conventions.md` | You need to create new schema modules, understand directory layout, work with chain-type customizations, or model polymorphic properties with `oneOf` |
| `references/error-response-patterns.md` | You need to declare error responses or understand which error module to use for a status code |
| `references/request-body-security-headers.md` | You're working with POST/PUT/PATCH endpoints, authentication/security, or HTTP header declarations |
| `references/inspection-checklist.md` | You're running an audit of an existing declaration (Workflow C) |

## Using subagents

For the Create workflow, parallelize the initial context gathering (Step 1) by spawning subagents to read the router, controller, view, and existing schemas simultaneously.

When running tests after changes, use the devcontainer skill if mix/elixir is not available on the host.
