# oastools Audit Recipes

Use these when authoring or auditing a declaration and you need a fact about the spec as a whole (not just one endpoint). For single-endpoint queries, see `references/spec-generation-and-verification.md`.

## Before running any recipe: regenerate

The generated spec is cache-like. A stale `.ai/tmp/openapi_public.yaml` produces false positives — e.g., a pre-migration spec may report tag-casing or path-prefix hits that the current codebase has already fixed.

```bash
.claude/skills/openapi-spec/scripts/generate-spec.sh
```

All recipes below assume `F=.ai/tmp/openapi_public.yaml` is set as a shell variable; substitute the full path if not.

## How each recipe is organized

Each recipe states: what it answers, the command, a baseline count (a tripwire, not a spec — not every hit is a bug; read the notes), and which skill sections cite it.

When a recipe's hit count goes down because you fixed drift, update the number here in the same PR. When it goes up, the PR introducing the regression should either fix it or document why in the recipe notes.

---

## Convention audits

Run these after any schema-touching change to catch drift a single-endpoint test run won't.

### A. Object schemas missing `additionalProperties: false`

```bash
oastools walk schemas -component -type object -detail -format json -q $F \
  | jq -rs '[.[] | select(.jsonPath | test("^\\$.components.schemas\\[[^.]+\\]$"))
                 | select(.schema.additionalProperties != false) | .name]'
```

Baseline: 12 hits, of which 6 are error-response schemas (`NotFoundResponse`, `ForbiddenResponse`, `UnauthorizedResponse`, `BadRequestResponse`, `NotImplementedResponse`, `JsonErrorResponse`) that intentionally omit `additionalProperties: false` — error payloads may carry extra debug fields. Real domain-schema drift is ~6 (`AuditReport`, `BlockCountdown`, `Counters`, `Response`, `SearchResult`, `StatsResponse`, `Status`).

Used by: `inspection-checklist.md` §2d, `schema-conventions.md` §"Composite object schemas".

### B. Operations missing `:unprocessable_entity` (422)

```bash
oastools walk operations -detail -format json $F \
  | jq -rs '[.[] | select(.operation.responses | has("422") | not)
                 | "\(.method) \(.path)"]'
```

Baseline: 21 hits. Some are likely-intentional (legacy endpoints without CastAndValidate, CSV exports whose only failure mode is 404). Triage per endpoint.

Used by: `inspection-checklist.md` §3c, `error-response-patterns.md` §"Choosing error responses for an operation".

### F. Operations missing `base_params()` (no `apikey` query param)

```bash
oastools walk operations -detail -format json $F \
  | jq -rs '[.[] | select((.operation.parameters // [] | map(.name) | index("apikey")) == null)
                 | "\(.method) \(.path)"]'
```

Baseline: 1 hit (`GET /v2/transactions/stats`).

Used by: `inspection-checklist.md` §3b, `SKILL.md` §"base_params() — always include".

### H. Operations missing summary or description

```bash
oastools walk operations -detail -format json $F \
  | jq -rs '[.[] | select(.operation.summary == null or .operation.description == null)
                 | "\(.method) \(.path)"]'
```

Baseline: 0 hits. Any hit is a straight fix.

Used by: `inspection-checklist.md` §3d.

### I. Tags violating kebab-case

```bash
oastools walk operations -detail -format json $F \
  | jq -rs '[.[] | .operation.tags[]?] | unique | map(select(contains("_")))'
```

Baseline: 0 hits. Any hit likely means a controller predates the kebab-case convention — migrate both the `tags(...)` call in the controller AND the registry entry in `specs/public.ex`.

Used by: `inspection-checklist.md` §3a, `SKILL.md` §"Controller prerequisites".

---

## Reuse and dedup scans

Run before writing new schema code to find consolidation candidates.

### D. Every inline enum in the spec

```bash
oastools walk schemas -detail -format json -q $F \
  | jq -rs '[.[] | select(.schema.enum != null)
                 | {path: .jsonPath, enum: .schema.enum}]'
```

Baseline: 71 inline enums. Post-process by grouping on `.enum` to find duplicates worth extracting per `schema-conventions.md` §"Domain-scoped shared schemas".

Used by: `schema-conventions.md` §"Domain-scoped shared schemas", `schema-conventions.md` §"Required: Ecto.Enum sync comments".

### E. Duplicate parameter definitions within one domain

```bash
oastools walk parameters -path '/v2/<domain>/*' -detail -format json -q $F \
  | jq -rs '[group_by(.parameter.name)[] | select(length > 1)
            | {name: .[0].parameter.name, count: length, paths: [.[].path]}]'
```

Returns any parameter declared on more than one endpoint under the given domain path. If the definitions are character-identical across endpoints, that's a helper extraction candidate per `inspection-checklist.md` §1e. Most domains return `[]`.

Used by: `inspection-checklist.md` §1e.

### G. Operations whose 200 response contains `oneOf`

```bash
oastools walk operations -detail -resolve-refs -format json $F \
  | jq -rs '[.[] | select(.operation.responses."200".content."application/json".schema
                           | tostring | contains("oneOf"))
                 | "\(.method) \(.path)"]'
```

Baseline: 7 hits — all transaction-list endpoints. Use as precedent when modeling polymorphic responses.

Used by: `schema-conventions.md` §"Polymorphic properties (`oneOf`)", `inspection-checklist.md` §2g.

### N. Schema subset/superset scan

```bash
oastools walk schemas -component -detail -format json -q $F \
  | jq -rs '[.[] | select(.jsonPath | test("^\\$.components.schemas\\[[^.]+\\]$"))
                 | {name, props: (.schema.properties // {} | keys)}]
            | map(select(.props | length > 0))'
```

Emits `{name, props}` tuples for every component schema. Post-process with jq (set difference on `.props`) to find pairs where `A.props ⊆ B.props` — candidates for `extend_schema` reuse per `schema-conventions.md` §"Schema reuse and naming for related schemas".

Used by: `SKILL.md` §Workflow A Step 3.2, `schema-conventions.md` §"Schema reuse and naming for related schemas".

---

## Precedent / discovery lookups

Run during authoring to find peer examples before writing new code.

### J. Endpoints consuming a specific parameter helper

```bash
oastools walk parameters -name <helper_name> -q $F
```

Authoritative about which endpoints *declare* the parameter in the spec — doesn't see controller-private helpers or inline params that happen to share a name.

Used by: `parameter-discovery.md` §"Find which controllers use a helper".

### K. All distinct parameter names reaching the spec

```bash
oastools walk parameters -detail -format json $F \
  | jq -rs '[.[] | .parameter.name] | unique'
```

Baseline: 92 distinct names (vs ~48 `def.*_param` in `general.ex`). Diff to find:
- Zombie helpers — defined in `general.ex` but never reaching the spec.
- Inline-only params — declared in controllers, candidates for promotion to `general.ex` if they are reusable.

Used by: `parameter-discovery.md` §"Browse all helpers".

### L. Request body discovery across POST/PUT/PATCH ops

```bash
oastools walk operations -method post -detail -format json $F \
  | jq -rs '.[] | select(.operation.requestBody)
               | {path, body: .operation.requestBody.content."application/json".schema}'
```

Baseline: 1 op (`POST /v2/smart-contracts/{address_hash_param}/audit-reports`). Repeat with `-method put` / `-method patch` as needed.

Used by: `request-body-security-headers.md` §"Discovering existing request body helpers".

### M. Operations declaring `security:`

```bash
oastools walk operations -detail -format json $F \
  | jq -rs '[.[] | select(.operation.security) | "\(.method) \(.path)"]'
```

Baseline: 0 in the public spec — `security:` is private/account-only. Regenerate against `specs/private.ex` for auth-bearing endpoints.

Used by: `request-body-security-headers.md` §"Security schemes".

### C. Properties missing `description:` in a named schema

```bash
oastools walk schemas -name <Schema> -detail -format json -q $F \
  | jq -rs '.[0].schema.properties | to_entries
            | map(select(.value.description == null)) | map(.key)'
```

Produces a mechanical shortlist for review. Still needs human judgment — tautological descriptions (that restate the property name) pass this filter but are equally bad; see `schema-conventions.md` §"Property descriptions".

Used by: `inspection-checklist.md` §2f, `schema-conventions.md` §"Property descriptions".
