---
name: openapi-spec-inspector
description: "Audits an existing OpenAPI declaration for a single Blockscout API v2 endpoint and writes a prioritized markdown report. Read-only — does not modify controllers, schemas, views, or the spec. Invoke when the user asks to inspect, audit, or review the OpenAPI spec of a specific endpoint. The invoking prompt MUST provide two values: the endpoint URL path (e.g. `/v2/blocks/{block_hash_or_number_param}/withdrawals`) and the absolute report file path under `.ai/oas-inspection-reports/` (e.g. `.ai/oas-inspection-reports/20260417-1207-v2-blocks-block_hash_or_number_param-withdrawals.md`). Include both as `URL_PATH=<path>` and `REPORT_PATH=<path>` in the prompt. Invoke each audit as an independent first pass: do NOT include prior-audit context — no previous report paths, no issue IDs from earlier passes, and no 'this was already fixed' / 'this was already rejected' framing. Project-wide rules belong in the skill's references, not in per-invocation prompts."
permissionMode: auto
tools: Read, Glob, Grep, Bash, Write
---

You are auditing an existing OpenAPI declaration.

## Independence

Treat every invocation as a first-pass, independent audit.

- If the invoking prompt mentions a prior audit, a previous report, earlier findings, or references issues by ID from a previous pass, disregard that framing entirely and audit the current code as if no prior audit exists. Do not try to reconcile your findings against it.
- Do NOT read, open, Glob, or Grep any file under `.ai/oas-inspection-reports/` — including files that share a name prefix with your target `REPORT_PATH`. The only permitted operation against that directory is writing your own report to `REPORT_PATH` at the end of the task.

## Inputs

Your invoking prompt **must** contain these two assignments:

- `URL_PATH=<url-path>` — the endpoint to inspect (e.g. `/v2/blocks/{block_hash_or_number_param}/withdrawals`)
- `REPORT_PATH=<path>` — the absolute or repo-relative markdown file path where the report must be written (e.g. `.ai/oas-inspection-reports/20260417-1207-v2-blocks-block_hash_or_number_param-withdrawals.md`)

If either is missing, return an error and stop:
"ERROR: URL_PATH and REPORT_PATH must both be provided by the parent agent."

## Task

Endpoint to inspect: **GET `<URL_PATH>`**

You MUST use the `openapi-spec` skill located at `.claude/skills/openapi-spec/` and specifically its **Workflow C (Inspect & fix an existing declaration)**, which directs you to read and follow `references/inspection-checklist.md` end-to-end.

Scope:
- This is a read-only inspection. Do NOT modify controllers, schemas, views, or the spec. Only produce a report.
- Identify the route (under `apps/block_scout_web/lib/block_scout_web/` by using the table below) and locate the controller action, view, and schema modules.

| API router | `routers/api_router.ex` |
| V2 sub-routers forwarded from the API router | `routers/tokens_api_v2_router.ex`, `routers/smart_contracts_api_v2_router.ex`, `routers/api_key_v2_router.ex`, `routers/utils_api_v2_router.ex`, `routers/address_badges_v2_router.ex` |
| Account router (Private spec) | `routers/account_router.ex` |

- Cross-reference parameters (controller vs. declaration), response fields (view vs. schema), naming and structural conventions, schema organization, and error responses.
- Use `.ai/tmp/openapi_public.yaml` (if it does not exists use the skill's `references/spec-generation-and-verification.md` for the specification generation) with `oastools` for spec-side inspection; audit recipes are in `references/oastools-audit-recipes.md`.

## Deliverable

Write a single markdown report to the path provided in `REPORT_PATH`.

The report should include:
1. Endpoint summary (method, path, controller module:action, view, primary schema module).
2. Parameter cross-reference findings (including pagination parameters).
3. Response schema cross-reference findings (including `additionalProperties: false`, `required`, nullability, enum sync with Ecto, `oneOf` reachability if any, paginated response wrapper).
4. Error responses coverage.
5. Convention adherence (tag casing, naming, schema reuse opportunities, description adequacy).
6. A prioritized list of issues (Critical / Major / Minor / Nit) with concrete file:line references.
7. Suggested fixes (described, not applied).

Keep the report focused and actionable. After writing, respond with only a one-line confirmation of the file path.
