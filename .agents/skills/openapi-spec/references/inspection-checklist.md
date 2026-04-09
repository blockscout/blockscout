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

**Known exceptions**: cross-cutting headers (`show-scam-tokens`, recaptcha headers) are conventionally undeclared. See `references/request-body-security-headers.md` for the gap details and recommended approach.

### 1b. Every declared parameter should be used

Check that each parameter in the `parameters:` list is actually consumed by the controller. Unused declared parameters create misleading API documentation.

### 1c. Three-way coupling is consistent

For each **path** parameter, verify:
1. The route segment name (`:param_name` in router) matches the `%Parameter{name: :param_name}` atom
2. The controller action's pattern match uses the same atom key
3. All three agree exactly

Read the route definition in the router file, the `%Parameter{}` definition, and the controller action head.

### 1d. Parameter types are accurate

For each parameter:
- Path params that are hashes should use `FullHash` or `AddressHash` schema
- Path params that are numbers should use `IntegerString` or `%Schema{type: :integer}`
- Enum params should have the correct `enum:` values (check the controller logic for valid values)
- Boolean params should use `%Schema{type: :boolean}`

## 2. Response field alignment

### 2a. Schema properties match view output

Read the view's render function and any `prepare_*` helper it calls. List every key in the output map.

Read the response schema module. List every key in `properties:`.

Compare:
- **Extra schema properties** (in schema but not in view): if in `required:`, this will cause test failures. If optional, it's technically valid but misleading.
- **Extra view keys** (in view but not in schema): if schema has `additionalProperties: false`, this will cause test failures. Otherwise it's undocumented output.
- **Type mismatches**: verify that each view output value matches its schema type (string, integer, object, array, nullable).

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

### 2d. additionalProperties: false is set

Check that `additionalProperties: false` is present on all object schemas. This is a project-wide convention that enables test-time enforcement.

### 2e. Chain-type fields are aligned

If the view has chain-type dispatching (check for `chain_type` case statements or `with_chain_type_fields` calls), the schema should also have a `ChainTypeCustomizations` module applying the same fields. Verify both sides handle the same chain types.

## 3. Convention compliance

### 3a. Controller prerequisites

Verify the controller has:
- `use OpenApiSpex.ControllerSpecs`
- `plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)`
- `tags(["domain-tag"])` — tag should match the router scope/resource group

### 3b. base_params() is included

Every public API operation should include `base_params()` in its parameters. Check that `base_params()` is present and isn't accidentally duplicated.

### 3c. Error responses are appropriate

Check which error cases the controller action handles (not_found, forbidden, etc.) and verify corresponding error responses are declared. See `references/error-response-patterns.md` for the status-code-to-module mapping.

At minimum, every operation should declare `:unprocessable_entity: JsonErrorResponse.response()` since CastAndValidate can always fail.

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

After identifying and fixing issues from sections 1-4, run the verification ladder. Each step catches a different class of problems, and earlier steps are faster.

### 5a. Compile

```bash
mix compile
```

Catches: missing schema modules, undefined parameter helper functions, operation names that don't match action functions, syntax errors in annotations. This is the fastest check — run it first.

### 5b. Generate the spec

```bash
mix openapi.spec.yaml --spec BlockScoutWeb.Specs.Public /tmp/openapi_check.yaml --start-app=false
```

For chain-specific endpoints, set `CHAIN_TYPE`:
```bash
CHAIN_TYPE=optimism mix openapi.spec.yaml --spec BlockScoutWeb.Specs.Public /tmp/openapi_check.yaml --start-app=false
```

Catches: schema resolution failures, circular references, malformed schema structures that compile but can't be inlined into the spec. The generated YAML can also be visually inspected or fed to external OpenAPI validators.

### 5c. Run controller tests

```bash
mix test apps/block_scout_web/test/block_scout_web/controllers/api/v2/<domain>_controller_test.exs
```

Catches: response schema mismatches — extra keys (via `additionalProperties: false`), missing required keys, type mismatches. Every `json_response/2` call in tests automatically validates the response body against the OpenAPI schema.

### 5d. Test coverage check

Check that tests exist and exercise the endpoint:

1. **Test file exists**: `test/block_scout_web/controllers/api/v2/<domain>_controller_test.exs`
2. **Tests hit the endpoint**: grep for the endpoint path in the test file
3. **All declared status codes are tested**: enumerate every status code in the operation's `responses:` and verify at least one test exercises each. Pay special attention to status codes with multiple triggering conditions (e.g., multiple 400 branches) — each condition ideally has its own test case

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

## Audit output

After completing the checklist, summarize findings as:

1. **Issues found** — concrete problems that will cause test failures or spec inaccuracies
2. **Convention deviations** — things that work but don't follow project conventions
3. **Improvement opportunities** — optional enhancements (better descriptions, missing examples, undeclared headers)
