# Spec Generation and Verification

## Generating the spec

Generate the public OpenAPI spec YAML from Blockscout's `open_api_spex` annotations:

```bash
.claude/skills/openapi-spec/scripts/generate-spec.sh
```

This produces `.ai/tmp/openapi_public.yaml` by default.

For chain-specific endpoints, pass `--chain`:

```bash
.claude/skills/openapi-spec/scripts/generate-spec.sh --chain arbitrum
```

This produces `.ai/tmp/openapi_public_arbitrum.yaml`.

To write to a custom path:

```bash
.claude/skills/openapi-spec/scripts/generate-spec.sh --chain optimism --output .ai/tmp/optimism_spec.yaml
```

The script always generates from `BlockScoutWeb.Specs.Public`, which aggregates all routes (API v2, tokens, smart contracts, and Etherscan-compatible endpoints).

### Behavior

- On success: prints the output file path and `SPEC_OK`. Mix output is suppressed.
- On failure: prints the captured mix output and `SPEC_FAIL`. Exit code 2.
- If `mix` is not available on the host, the script automatically delegates to the devcontainer.
- The script creates `.ai/tmp/` if it does not exist.

## Verifying with oastools

After generating the spec, use `oastools` to validate and inspect it. All examples below assume the default output path — adjust if you used `--output` or `--chain`.

**Keep queries precise.** Always narrow by exact `-path` and `-method` to avoid large outputs that consume context. Never omit filters when you know the target endpoint.

### Validate the full spec

```bash
oastools validate .ai/tmp/openapi_public.yaml
```

### Check that an endpoint exists

```bash
oastools walk operations -path "/v2/addresses/{address_hash_param}" .ai/tmp/openapi_public.yaml
```

### Get operation parameters

```bash
oastools walk parameters -detail -format json -method get -path "/v2/addresses/{address_hash_param}" .ai/tmp/openapi_public.yaml | jq 'del(.path)'
```

Filter by parameter location when you only need query or path params:

```bash
oastools walk parameters -detail -format json -in query -method get -path "/v2/addresses/{address_hash_param}/transactions" .ai/tmp/openapi_public.yaml | jq 'del(.path)'
```

### Get response schema

```bash
oastools walk responses -detail -format json -status 200 -method get -path "/v2/addresses/{address_hash_param}" .ai/tmp/openapi_public.yaml | jq 'del(.path)'
```

Always specify `-status` to get only the response code you need.

### Inspect a specific schema

```bash
oastools walk schemas -detail -format json -name AddressResponse .ai/tmp/openapi_public.yaml | jq 'del(.jsonPath)'
```

## Typical verification workflow

After creating or modifying an OpenAPI declaration:

1. **Generate** the spec:
   ```bash
   .claude/skills/openapi-spec/scripts/generate-spec.sh
   ```

2. **Validate** the full spec:
   ```bash
   oastools validate .ai/tmp/openapi_public.yaml
   ```

3. **Inspect** the target operation — use exact path and method:
   ```bash
   oastools walk parameters -detail -format json -method get -path "/v2/<endpoint_path>" .ai/tmp/openapi_public.yaml | jq 'del(.path)'
   oastools walk responses -detail -format json -status 200 -method get -path "/v2/<endpoint_path>" .ai/tmp/openapi_public.yaml | jq 'del(.path)'
   ```

4. **Run tests** to verify response schemas match the view output (use the `run-tests` skill).

## Spec-wide audits

Single-endpoint queries above answer "did I declare this right?" For "does the whole spec still follow our conventions?", use `references/oastools-audit-recipes.md`. Minimum sweep after any schema-touching change: recipe A (additionalProperties), B (422 coverage), F (base_params), I (tag casing).

Always regenerate before auditing — the generated spec is cache-like, and a stale YAML produces false positives.
