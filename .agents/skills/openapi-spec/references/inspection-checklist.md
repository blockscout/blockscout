# Inspection Checklist

Use this checklist to systematically audit an existing OpenAPI declaration. Work through each section, reading the relevant files as needed.

## 1. Parameter completeness

### 1a. Every parameter the controller reads should be declared

Read the controller action function. Identify every key it reads from:
- `params` pattern match in the function head (path + query params)
- `conn.body_params` (request body params)
- `conn.req_headers` (header params)
- Calls to helper functions that read from params (e.g., `paging_options(params)`, `token_transfers_types_options(params)`, `fetch_scam_token_toggle(conn)`)

Cross-reference with the `parameters:` list in the `operation` macro. Every parameter that affects the endpoint's behavior should be declared.

Spec-side enumeration in one command: `oastools walk parameters -path <X> -method <Y> -q .ai/tmp/openapi_public.yaml`. Controller side still needs to be read for the comparison.

**Known exceptions**: cross-cutting headers (`show-scam-tokens`, recaptcha headers) are conventionally undeclared. See `references/request-body-security-headers.md` for the gap details and recommended approach.

### 1b. Every declared parameter should be used

Check that each parameter in the `parameters:` list is actually consumed by the controller. Unused declared parameters create misleading API documentation.

### 1c. Three-way coupling is consistent

For each **path** parameter, verify:
1. The route segment name (`:param_name` in router) matches the `%Parameter{name: :param_name}` atom
2. The controller action's pattern match uses the same atom key
3. All three agree exactly

Read the route definition in the router file, the `%Parameter{}` definition, and the controller action head.

Spec side: `oastools walk parameters -in path -path <X> -method <Y> -detail -format json .ai/tmp/openapi_public.yaml | jq '.parameter.name'`.

### 1d. Parameter types are accurate

For each parameter:
- Path params that are hashes should use `FullHash` or `AddressHash` schema
- Path params that are numbers should use `IntegerString` or `%Schema{type: :integer}`
- Enum params should have the correct `enum:` values (check the controller logic for valid values)
- Boolean params should use `%Schema{type: :boolean}`

### 1e. No duplicated inline parameters

For each inline `%Parameter{}` struct in the operation, scan the other operations in the same controller for identical or near-identical structs (same `name`, `in`, `schema`, and `description`). Duplicated inline parameters are a maintenance risk — changing one without updating the other creates silent inconsistencies.

Mechanical scan across the whole domain: recipe E in `references/oastools-audit-recipes.md` groups same-name parameters across all endpoints under one path prefix in a single pass.

If duplication is found, extract the parameter into a reusable helper function:
- **Generic concept** (address hashes, transaction hashes, block numbers — useful across multiple controllers): add a helper to `general.ex` following the conventions in `references/parameter-discovery.md`.
- **Domain-specific concept** (e.g., an Arbitrum message direction — only meaningful within one controller): add a private helper function in the same controller. This keeps the chain-specific concern contained without polluting the shared `general.ex`.

## 2. Response field alignment

### 2a. Schema properties match view output

Read the view's render function and any `prepare_*` helper it calls. List every key in the output map.

Read the response schema module. List every key in `properties:`.

Compare:
- **Extra schema properties** (in schema but not in view): if in `required:`, this will cause test failures. If optional, it's technically valid but misleading.
- **Extra view keys** (in view but not in schema): if schema has `additionalProperties: false`, this will cause test failures. Otherwise it's undocumented output.
- **Type mismatches**: verify that each view output value matches its schema type (string, integer, object, array, nullable).

Schema-side key list in one command: `oastools walk schemas -name <Schema> -detail -format json .ai/tmp/openapi_public.yaml | jq '.[0].schema.properties | keys'`.

### 2b. Type precision — check Ecto schemas for enums and constraints

The view layer is lossy about types. A field that renders as a plain string may actually be an `Ecto.Enum` with a fixed set of values. For each string-typed property in the OpenAPI schema:

1. Find the corresponding Ecto schema module in `apps/explorer/lib/explorer/chain/`. Grep for `Ecto.Enum` in that file.
2. If the field is an `Ecto.Enum`, the OpenAPI property should use `enum: [...]` with the correct values, not just `type: :string`.
3. If the property already uses `enum:`, verify the values are **complete and current** by comparing against the Ecto enum definition. New values may have been added to the Ecto schema without updating the OpenAPI schema — this is a silent breakage where `CastAndValidate` rejects the new value on input.
4. Verify there is a code comment on the enum property pointing to the source Ecto field (e.g., `# Enum values must be kept in sync with Explorer.Chain.<Module> :<field_name> field.`). If missing, add one.
5. Check existing schemas in the same domain for precedent — similar entities often already use enum for comparable fields.

Also check for other type refinements: large integers serialized as strings should use `IntegerString`, hash fields should use `FullHash`/`AddressHash`, timestamps should use `Timestamp`/`TimestampNullable`.

See `references/schema-conventions.md` section "Determining property types from Ecto schemas" for the full Ecto-to-OpenAPI type mapping.

### 2c. Required list is accurate

Every key the view always emits should be in `required:`. Keys that are conditional or sometimes `nil` should either:
- Not be in `required:` (if the key might be absent)
- Be in `required:` but have `nullable: true` on the schema (if the key is always present but sometimes null)

See `references/schema-conventions.md` section "Nullable fields" for the full nullable handling rules, including why `type: :null` / `anyOf: [%Schema{type: :null}, …]` (OpenAPI 3.1) is invalid here.

### 2d. additionalProperties: false is set

Check that `additionalProperties: false` is present on all object schemas. This is a project-wide convention that enables test-time enforcement.

Spec-wide audit: recipe A in `references/oastools-audit-recipes.md` lists every component object schema that violates this. Error-response schemas (`NotFoundResponse`, `ForbiddenResponse`, etc.) intentionally omit it — real domain-schema drift is typically the remainder.

### 2e. Chain-type fields are aligned

If the view has chain-type dispatching (check for `chain_type` case statements or `with_chain_type_fields` calls), the schema should also have a `ChainTypeCustomizations` module applying the same fields. Verify both sides handle the same chain types. See `references/schema-conventions.md` section "Chain-type customization pattern" for the dispatch mechanism and where `ChainTypeCustomizations` modules are conventionally placed.

### 2f. Property descriptions are adequate

Scan all properties in the schema. For each property that has no `description:` (or a tautological one that restates the name), ask: "Would an API consumer unfamiliar with this chain's internals understand this property from its name alone?"

Flag properties that fail this test. Common patterns to watch for:

- **Domain jargon** (`before_acc_hash`, `callvalue`) — needs explanation of what the term means
- **Ambiguous roles** (`caller_address_hash`, `destination_address_hash`) — needs "who" and "on which chain"
- **Unclear chain context** (`block_number` in a cross-chain object) — needs "Parent chain" or "Rollup"
- **Enum values without lifecycle explanation** (`status` with `["initiated", "sent", "confirmed", "relayed"]`) — needs description of what triggers each transition
- **Tautological descriptions** ("Withdrawal status." on `status`) — count as missing; rewrite or remove

Self-documenting compound names (`origination_transaction_block_number`) and well-known primitives (`token.symbol`) don't need descriptions.

Mechanical shortlist of properties lacking `description:`: recipe C in `references/oastools-audit-recipes.md`. Human review still needed — tautologies pass this filter.

See `references/schema-conventions.md` section "Property descriptions" for the full guidelines and before/after examples.

### 2g. `oneOf`/`anyOf` variant reachability

For each property in the response schema that uses `oneOf` or `anyOf`, verify that every variant is producible by this endpoint's controller action:

1. List the variants in the `oneOf`/`anyOf` and identify the discriminator value(s) each covers.
2. Read the controller action. Trace which code paths lead to the view's render function. Identify which discriminator values the controller can pass to the view.
3. Read the view's render function and its helpers. Confirm which variants the view can actually emit for the data the controller provides.
4. Compare: flag any variant whose discriminator value(s) can never be produced by this endpoint.

**If unreachable variants are found:** The schema overpromises to API consumers. Create a narrowed schema via `extend_schema` that overrides only the polymorphic property, keeping just the reachable variants. See `references/schema-conventions.md` section "Helper.extend_schema/2".

To find all endpoints whose 200 response currently uses `oneOf` (for precedent), run recipe G in `references/oastools-audit-recipes.md`.

This check is especially important for endpoints that filter by a specific discriminator value (e.g., a DA-type lookup that always returns one DA variant, but references a shared batch schema containing all DA variants).

## 3. Convention compliance

### 3a. Controller prerequisites

Verify the controller has:
- `use OpenApiSpex.ControllerSpecs`
- `plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)`
- `tags(["domain-tag"])` — kebab-case (e.g. `"internal-transactions"`, `"smart-contracts"`, `"account-abstraction"`); should match the router scope/resource group
- The tag is registered in `specs/public.ex` — in `@default_api_categories` (base), in the appropriate `case @chain_identity` branch of `chain_type_category/0` (chain-type), or already pinned as `"legacy"`. An un-registered tag still renders per-operation but has no guaranteed ordering in the generated spec.

Spec-wide tripwire: recipe I in `references/oastools-audit-recipes.md` returns any tag containing `_`. The baseline is `[]` — any hit likely means a controller predates the kebab-case convention.

### 3b. base_params() is included

Every public API operation should include `base_params()` in its parameters. Check that `base_params()` is present and isn't accidentally duplicated.

Spec-wide audit: recipe F in `references/oastools-audit-recipes.md` lists operations missing `apikey`.

### 3c. Error responses are appropriate

Check which error cases the controller action handles (not_found, forbidden, etc.) and verify corresponding error responses are declared. See `references/error-response-patterns.md` for the status-code-to-module mapping.

At minimum, every operation should declare `:unprocessable_entity: JsonErrorResponse.response()` since CastAndValidate can always fail.

Spec-wide audit: recipe B in `references/oastools-audit-recipes.md` lists operations missing 422. Some are likely-intentional (legacy endpoints, CSV exports) — triage per endpoint.

### 3d. Summary and description

- `summary:` should be a short imperative sentence (shown in endpoint lists)
- `description:` should add useful detail beyond the summary
- Both should be present

### 3e. Operation name matches action

The first argument to `operation/2` must match the controller action function name:
```elixir
operation :transaction, ...    # matches def transaction(conn, params)
```

## 4. Schema module organization

### 4a. Schema is in the right location

Check that the schema module follows directory conventions:
- Domain schemas under `schemas/api/v2/<domain>.ex` or `schemas/api/v2/<domain>/*.ex`
- Chain-specific schemas under `schemas/api/v2/<chain>/`
- Leaf types under `schemas/api/v2/general/`

See `references/schema-conventions.md` for full conventions.

### 4b. Module naming follows conventions

`BlockScoutWeb.Schemas.API.V2.<Domain>` for base schemas, `BlockScoutWeb.Schemas.API.V2.<Domain>.Response` for response wrappers.

## 5. Verification

After identifying and fixing issues from sections 1-4, run the verification ladder described in the "Verification" section of `SKILL.md` (compile → generate-spec → controller tests). Each step catches a different class of problems, and earlier steps are faster.

### 5a. Test coverage check

Check that tests exist and exercise the endpoint:

1. **Test file exists**: `test/block_scout_web/controllers/api/v2/<domain>_controller_test.exs`
2. **Tests hit the endpoint**: grep for the endpoint path in the test file
3. **All declared status codes are tested**: enumerate every status code in the operation's `responses:` and verify at least one test exercises each. Pay special attention to status codes with multiple triggering conditions (e.g., multiple 400 branches) — each condition ideally has its own test case. Spec-side enumeration: `oastools walk responses -path <X> -method <Y> -q .ai/tmp/openapi_public.yaml`.

### Minimal test templates

If no tests exist for the endpoint:

```elixir
# For a list endpoint (empty list, zero factory data)
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

# For a not-found case
test "returns 404", %{conn: conn} do
  resource = build(:<factory_name>)    # build but don't insert
  request = get(conn, "/api/v2/<path>/#{resource.id}")
  assert %{"message" => "Not found"} = json_response(request, 404)
end

# For a validation error
test "returns 422 on invalid input", %{conn: conn} do
  request = get(conn, "/api/v2/<path>/invalid_value")
  assert %{"errors" => [_]} = json_response(request, 422)
end
```

## 6. Spec-wide sweep

Independent of any single-endpoint audit, run this sweep once per work session to catch drift introduced elsewhere in the codebase. Regenerate the spec first — stale YAML produces false positives.

- Recipe A — object schemas missing `additionalProperties: false`
- Recipe B — operations missing 422
- Recipe F — operations missing `apikey` (base_params)
- Recipe I — tags violating kebab-case

Full recipes in `references/oastools-audit-recipes.md`. Results belong in the "Convention deviations" section of the audit output below.

## Audit output

After completing the checklist, summarize findings as:

1. **Issues found** — concrete problems that will cause test failures or spec inaccuracies
2. **Convention deviations** — things that work but don't follow project conventions
3. **Improvement opportunities** — optional enhancements (better descriptions, missing examples, undeclared headers)
