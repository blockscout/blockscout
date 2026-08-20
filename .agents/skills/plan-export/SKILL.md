---
name: plan-export
description: "Write a detailed, phased implementation plan for a GitHub issue, and save it to a file."
argument-hint: [issue-number (optional)]
disable-model-invocation: true
---

# Plan Export Skill

This skill composes a detailed, phased implementation plan for a GitHub issue in the Blockscout Elixir backend (`blockscout/blockscout`). The issue number can be passed as `$1` or discovered from the conversation context (e.g., after a preceding issue-publish step that left a URL in scrollback). The plan is designed for a developer who knows Elixir but has limited familiarity with Blockscout-specific patterns and the affected app(s).

## Prerequisites

Before invoking this skill, the agent must already understand the scope of the changes through prior conversation. The skill assumes:

1. The feature/issue has been thoroughly discussed
2. The agent understands what needs to be changed
3. **The agent has read every file it intends to name in the plan.** If a `.ai/pre-plan/<slug>/changes-to-discuss-*.md` file exists for this feature — written by the sibling `describe-changes` skill during the earlier, pre-issue scoping stage — treat it as a useful starting inventory, not a substitute for reading. `describe-changes` produces a rough first pass to confirm a problem is worth turning into an issue; by the time `plan-export` runs, the issue already exists and the phased plan needs the fuller wiring picture. File names and module layout in this codebase can be misleading: a change to a GenServer routinely requires touching its registration in `application.ex`/`supervisor.ex`, a route not obviously implied by a controller's name, or an OpenAPI schema module that isn't visible from the changed file alone. Before any file appears in a phase's "Files to Modify/Create" list, read it in the current conversation — do not guess from its path, and do not carry a claim forward from `describe-changes`'s output without having read the file yourself. This includes every wiring hop up the chain: context modules that call into the changed module, `application.ex`/`supervisor.ex` if a process is added or reconfigured, and `router.ex` if an API route is added.

## Workflow

### 0. Determine Issue Number

Before proceeding, resolve the GitHub issue number to use throughout the plan:

1. **If `$1` is provided and non-empty**, use it directly as the issue number.
2. **Otherwise**, search the current conversation for:
   - A GitHub issue URL matching `https://github.com/blockscout/blockscout/issues/<number>` — extract the number from the URL.
   - An explicit issue number reference like `#<number>` or `issue <number>`.
3. **If multiple distinct issue numbers are found** in the conversation, list them and ask the user which one to use.
4. **If no issue number can be determined** from either source, ask the user to provide one before continuing.

Once resolved, use this number as `$1` for all subsequent steps. The issue lives in `blockscout/blockscout` (this repo's `origin` remote). If the working copy's remote points elsewhere (e.g. a fork), resolve the real repo first with `gh repo view --json owner,name -q '"\(.owner.login)/\(.name)"'` before building the issue URL — this mirrors the resolution the sibling `review-described-changes` skill uses.

### 1. Identify Applicable Guidelines

Determine which guideline files apply to the discussed changes. Sources of authoritative guidance in this repo, in order of specificity:

- **Root `AGENTS.md`** — architecture guidance that applies regardless of app: API/indexer mode placement rules, the `configure_mode_dependent_process`/`configure_chain_type_dependent_process`/`only_in_mode` helper piping, and the cache-pattern reference for telling active updaters apart from passive caches.
- **Root `CLAUDE.md`** — points back to `AGENTS.md` and any other pinned repo-wide conventions.
- **Topical rule files under `.claude/rules/*.md`** — each covers one concern; read every file present, since the set can grow over time. As of this writing:
  - `chain-types.md` — the canonical list of valid `CHAIN_TYPE` values
  - `testing-conventions.md` — how to wrap chain-type-conditional tests
  - `elixir-runtime-over-typespec.md` — trust the runtime over `@spec`/`@type` when they disagree
  - `mix-test-awareness.md` — never invoke `mix test` directly
- **`.github/CONTRIBUTING.md`** — repo-wide contribution conventions (commit granularity, regression-test-first ordering for bug fixes, incompatible-change callouts).

Unlike some sibling Blockscout repos, there is no per-app tier of guideline files here (no `apps/explorer/AGENTS.md`, no memory-bank directory) — the sources above are the complete set. If a source doesn't exist, skip it silently; do not invent one.

### 2. Determine CHAIN_TYPE

Resolve which `CHAIN_TYPE` the plan targets before composing it:

- Default to `CHAIN_TYPE=default` — this covers chain-agnostic work, which is the common case.
- Only treat the plan as chain-specific if the issue or conversation explicitly calls out a chain (e.g., the issue names Arbitrum, Optimism, zkSync, etc.). Do not infer a chain from an incidental mention, a merge commit, or a review comment about another chain. See `.claude/rules/chain-types.md` for the canonical `CHAIN_TYPE` values and their resolved identities.
- State the resolved `CHAIN_TYPE` explicitly in the plan's preamble — every phase's verification steps pass it to the `compile-project`/`run-tests`/`code-quality`/`dialyzer-reviewer` skills and agents, so it must be pinned down once, up front, rather than re-derived per phase.
- If chain-specific, any phase that adds or modifies chain-scoped tests must follow `.claude/rules/testing-conventions.md`: wrap the **entire** `describe` block (and any related helper functions) with `if @chain_type == :x do ... end` from the outside — never nest the conditional inside the `describe` block, since that produces empty `describe` blocks in test output for every other chain type.

### 3. Read All Applicable Rules

**MANDATORY:** Read each applicable rule file identified in step 1 using the Read tool before composing the plan. Do not skip this step or guess rule contents.

For each rule file:

1. Read the complete file content
2. Note specific requirements, patterns, and constraints (e.g., the mode/chain-type helper piping order in `AGENTS.md`, the outside-in `describe`-block wrapping in `testing-conventions.md`, the runtime-over-typespec rule, the mandatory `run-tests`/`code-quality`/`dialyzer-reviewer` delegation instead of raw `mix` invocations)
3. Incorporate these into the implementation plan

### 4. Compose the Implementation Plan

**This skill is the complete and only source for the plan's format.** The template below and the slice-marker rules define every convention you need — section order, marker syntax, all of it. Because the format is fully specified here, you never need to look at another plan to copy its conventions, and you must not: do not open or grep any other file under `.ai/impl_plans/`. Reading a sibling plan does two kinds of harm — it spends context on a document irrelevant to this issue, and, more insidiously, it anchors you to another feature's scope, phasing, and wording, biasing the plan you're writing now. If you're unsure your markers are correct, don't compare against an example — write them per this template and let the step-6 `--inspect` check prove them. (The pattern examples this skill asks you to cite are *source and test files for this feature*, referenced by path — never other plans.)

Create a detailed Markdown document at `.ai/impl_plans/issue-$1.md` with the following structure.

**Slice markers — required.** Wrap every section in paired, namespaced HTML-comment markers so the plan can be sliced deterministically by `.agents/skills/plan-export/scripts/slice_impl_plan.py` (headings alone are unreliable — plans embed code blocks and exact documentation that legitimately contain `#`/`##` as content). Rules:

- Wrap the **preamble** — the title, issue link, CHAIN_TYPE, Overview, and Applicable Guidelines — in one region `slug="preamble"`.
- Wrap **each phase** in its own region `slug="phase-<n>"`, where `<n>` is the phase's sequential number (1, 2, 3 … contiguous, matching the `## Phase <n>` heading). Number only the phases you actually emit. Put `title="<short phase name>"` on the begin marker.
- Wrap the **Final Checklist** in `slug="final-checklist"`.
- Markers start at column 0. Every `begin` has a matching `end` with the same slug; never nest them. No real content may live outside a region (blank lines and `---` rules between regions are fine). A `title` must not contain a double-quote.

The structure, with markers in place:

```markdown
<!-- impl-plan:begin slug="preamble" -->
# Implementation Plan for Issue #$1

**GitHub Issue:** https://github.com/blockscout/blockscout/issues/$1

**CHAIN_TYPE:** `default` (or the specific chain type identifier from `.claude/rules/chain-types.md`, with a one-line justification for why this plan is chain-specific)

## Overview

[Brief summary of what needs to be implemented - 2-3 sentences. Name the affected app(s) explicitly, e.g., `apps/explorer`, `apps/block_scout_web`, `apps/indexer`, `apps/ethereum_jsonrpc`.]

## Applicable Guidelines

[List the rule files that were read and applied, with brief notes on key requirements from each. Examples:]

- `AGENTS.md` — mode/chain-type process placement, helper piping order
- `CLAUDE.md` — repo-wide pointer, no additional conventions beyond `AGENTS.md`
- `.claude/rules/testing-conventions.md` (if chain-specific) — outside-in `describe`-block wrapping
- `.claude/rules/elixir-runtime-over-typespec.md` (if typespecs are touched) — trust runtime shape over `@spec`
- `.github/CONTRIBUTING.md` — commit/PR conventions applied
<!-- impl-plan:end slug="preamble" -->

---

<!-- impl-plan:begin slug="phase-1" title="[Phase Name - Functional Changes]" -->
## Phase 1: [Phase Name - Functional Changes]

### Objective

[What this phase accomplishes]

### Files to Modify/Create

[List in dependency order — dependencies first, consumers after. Include every wiring hop: context modules that call into the changed module, `application.ex`/`supervisor.ex` if a process is added or reconfigured, `router.ex` if an API route is added, and any single-source-of-truth registration files (e.g., `apps/explorer/lib/explorer/chain/cache/background_migrations.ex` for heavy-index migrations, OpenAPI schema modules under `apps/block_scout_web/lib/block_scout_web/schemas/api/`, `docker-compose/envs/common-blockscout.env` for any new environment variable).]

- `apps/<app>/lib/<module_path>.ex`: [Brief description of changes]
- `apps/<app>/lib/<context>.ex`: [New `alias`/call site wiring the new module in]
- ...

### Implementation Details

[Explain WHAT needs to be changed and WHY. Focus on Blockscout-specific context the developer needs to understand:]

- What existing patterns/helpers to reuse and where to find them (e.g., `Explorer.Chain.MapCache` for passive on-demand caches, `configure_mode_dependent_process`/`configure_chain_type_dependent_process`/`only_in_mode` from `Explorer.Application` for process registration, `LastFetchedCounter.upsert()` for active periodic updaters — see `AGENTS.md`'s Cache Pattern Reference for how to tell these apart)
- What project conventions apply (naming, `with`/`case` idioms, OpenApiSpex `operation` macros for API actions, trusting runtime shape over `@spec`/`@type` per `.claude/rules/elixir-runtime-over-typespec.md`)
- How this change fits into the existing architecture (API vs. indexer mode placement per `AGENTS.md`, chain-type gating per `.claude/rules/chain-types.md`)
- Any non-obvious dependencies or side effects (a GenServer not registered in `application.ex`/`supervisor.ex` never starts; a route not added to `router.ex` silently 404s; a heavy-index migration not wired into `background_migrations.ex` never reports completion; an OpenAPI schema change not recompiled leaves the served spec stale; a new environment variable not added to `docker-compose/envs/common-blockscout.env` leaves local Docker setups silently out of sync with `runtime.exs`)

**Do NOT include code snippets.** The developer knows Elixir — explain the project-specific aspects they need to understand. Use file paths to point at existing patterns rather than reproducing them inline.

### Unit Tests

- **File:** `apps/<app>/test/<mirror-of-lib-path>_test.exs` (mirrors the `lib/` path, e.g. `apps/explorer/lib/explorer/chain/transaction.ex` → `apps/explorer/test/explorer/chain/transaction_test.exs`)
- **Purpose:** [What functionality this test validates]
- **Scenarios to cover:**
  - [List scenarios: success cases, error handling, edge cases]
- **Reference:** [Point to a similar existing test as a pattern example, e.g., `apps/explorer/test/explorer/chain/...`, `apps/indexer/test/indexer/fetcher/...`]
- **Factories:** seed test data via `Explorer.Factory` (`apps/explorer/test/support/factory.ex`) using `insert(:schema_name)` / `build(:schema_name)`. Every test runs inside its own rolled-back Ecto sandbox transaction, so there is no shared-fixture blast radius here. **The one exception:** if this phase adds or changes a field inside an existing `<schema>_factory` function in `Explorer.Factory` itself, treat that as a blast-radius change — state which other tests call that factory and might assert on its exact shape, since `Explorer.Factory` is shared across all four apps' test suites.
- **Chain-type-gated tests** (if this plan is chain-specific, see step 2 above): wrap the entire `describe` block (and any helpers) with `if @chain_type == :x do ... end` from the outside, per `.claude/rules/testing-conventions.md` — never nest the conditional inside the `describe` block.

### Verification

1. **Compile:** invoke the `compile-project` skill for `CHAIN_TYPE=<resolved>` — never run `mix compile` directly.
2. **Test:** invoke the `run-tests` skill, scoped to the module(s)/test file(s) this phase touched — never run `mix test` directly (see `.claude/rules/mix-test-awareness.md`).
3. **Code quality:** invoke the `code-quality` agent for `CHAIN_TYPE=<resolved>` (formatting, Credo, spell check) — never run `mix format`/`mix credo`/`cspell` directly.
4. **Types:** invoke the `dialyzer-reviewer` agent for `CHAIN_TYPE=<resolved>`. A phase is meant to be a self-contained, independently reviewable/committable unit, so run it here rather than deferring every type check to the very end — that way type problems surface while the phase's context is still fresh, not batched across the whole plan.
5. Fix any problems found before proceeding to the next phase.
<!-- impl-plan:end slug="phase-1" -->

---

<!-- impl-plan:begin slug="phase-2" title="[Phase Name - Additional Functional Changes]" -->
## Phase 2: [Phase Name - Additional Functional Changes]

[Same structure as Phase 1, including its own unit tests]
<!-- impl-plan:end slug="phase-2" -->

---

<!-- impl-plan:begin slug="phase-N" title="Controller / Integration Tests" -->
## Phase N: Controller / Integration Tests

### Objective

Verify the implementation works correctly end-to-end (HTTP handlers, real database, real configuration).

### Files to Create

- `apps/block_scout_web/test/block_scout_web/controllers/<version>/<resource>_controller_test.exs` (or the equivalent location for this change — legacy HTML controllers live flat under `controllers/`, API v2 under `controllers/api/v2/`, RPC-style endpoints under `controllers/api/rpc/`), or a `apps/block_scout_web/test/block_scout_web/features/*_test.exs` Wallaby feature test if the change is UI-facing

### Test Scenarios

- **Purpose:** [What real-world functionality this validates]
- **Scenarios to cover:** [List scenarios with expected outcomes]
- **Reference:** [Point to a similar existing controller/feature test as a pattern example]
- **OpenAPI-backed endpoints** (if applicable): if the endpoint carries an `open_api_spex` `operation` macro, also assert the response matches the compiled spec using `apps/block_scout_web/test/support/api_schema_assertions.ex` (see existing usages under `apps/block_scout_web/test/block_scout_web/schemas/`)
- **Chain-type-gated endpoints** (if applicable): same outside-in wrapping rule as unit tests.

### Verification

Same four-step sequence as Phase 1 (compile-project → run-tests → code-quality → dialyzer-reviewer), scoped to the new test file(s) and, for the test suite run, the full affected app.
<!-- impl-plan:end slug="phase-N" -->

---

<!-- impl-plan:begin slug="final-checklist" -->
## Final Checklist

- [ ] All phases completed and verified (including each phase's compile/test/quality/dialyzer pass)
- [ ] Full test suite passes for the affected app(s) via the `run-tests` skill (not just the phase-scoped subsets)
- [ ] `code-quality` agent run clean for `CHAIN_TYPE=<resolved>` across all changed files
- [ ] `dialyzer-reviewer` agent run clean for `CHAIN_TYPE=<resolved>`
- [ ] Migrations apply cleanly on a fresh DB and on top of the previous schema (if migrations were added) — generated via the `ecto-migration` skill, or, for large-table index changes, the `heavy-db-index-operation` skill (which also updates `apps/explorer/lib/explorer/chain/cache/background_migrations.ex` — an easy-to-forget registration point)
- [ ] OpenAPI spec updated via the `openapi-spec` skill and recompiled via `.agents/skills/openapi-spec/scripts/generate-spec.sh` (if an API endpoint's request/response shape changed)
- [ ] `docker-compose/envs/common-blockscout.env` updated via the `update-common-blockscout-env` skill (if a new environment variable was introduced)
- [ ] `apps/<app>/mix.exs` updated (if a new dependency was added)
<!-- impl-plan:end slug="final-checklist" -->

```

### 5. Content Guidelines

**MUST INCLUDE:**

- Reference to the GitHub issue (with full URL)
- The affected app(s), named explicitly
- The resolved `CHAIN_TYPE`, with justification if chain-specific
- List of applicable guidelines that were read and applied
- Phases that allow incremental verification
- Explanations of WHAT to change and WHY (Blockscout-specific context)
- References to existing code as pattern examples (file paths, not snippets)
- Specific test scenarios with clear descriptions
- Verification steps for each phase, delegated to the named skills/agents

**MUST NOT INCLUDE:**

- Code snippets for functional changes or tests (developer knows Elixir)
- Time estimates
- Assumptions about deep Blockscout-specific knowledge — name the helpers, macros, and registration files explicitly
- Documentation updates — do not invent doc edits or speculate about which files would need updating
- Vague instructions like "update as appropriate"
- Raw `mix`/shell invocations in verification steps — always delegate to `compile-project`, `run-tests`, the `code-quality` agent, or the `dialyzer-reviewer` agent

**PHASE ORGANIZATION:**

1. Only include phases that have actual work to do — omit empty phases.
2. **Keep phases small and focused.** Each phase should have a single, clear objective that can be completed, tested, and reviewed as an independent unit. Prefer multiple small phases over fewer large ones.
3. Organize phases so each can be independently verified with its own tests.
4. Start with core functionality, then tests.
5. Each phase should build on the previous one.

**Phase Size Rationale**: Since each phase's code goes through review (and gets its own compile/test/quality/dialyzer pass, per step 4's Verification section), smaller phases are easier to review thoroughly. Catching issues early (e.g., in a schema or migration phase) prevents building faulty logic on top of flawed foundations.

**Examples of Good Phase Breakdown:**

- ❌ **Too Large**: Phase 1: Migration + schema + context function + controller + view + OpenAPI spec + all tests
- ✅ **Better**: Phase 1: Migration + Ecto schema (with migration/factory test), Phase 2: Context function + unit tests, Phase 3: Controller + router wiring + OpenAPI spec + controller test
- ❌ **Too Large**: Phase 1: New indexer fetcher + supervisor registration + cache + config + tests
- ✅ **Better**: Phase 1: Fetcher module + unit tests, Phase 2: `application.ex`/`supervisor.ex` registration + mode/chain-type gating, Phase 3: Cache wiring + integration test

**DEPENDENCY ORDERING:**

1. **Between Phases**: Changes in a subsequent phase must build on top of changes from previous phases. Never reference functionality that will be created in a later phase.
2. **Within a Phase**: In the "Implementation Details" section, describe dependencies before things that use them:
   - If a controller uses a context function, describe the context function first, then the controller
   - If a context function uses an Ecto schema, describe the schema first, then the context function
   - If a GenServer needs mode/chain-type gating, describe the gating helper piping first, then the process definition
   - If a test requires factory data, describe the factory addition first, then the test
3. **Files Listing Order**: In "Files to Create/Modify" sections, list files in dependency order (dependencies first, context-module wiring hops after the new file, registration files like `application.ex`/`supervisor.ex`/`router.ex` last so the new item is referenceable when registered).

### 6. Write the Plan File

Save the plan to:

```text
.ai/impl_plans/issue-$1.md
```

Create the `.ai/impl_plans/` directory if it does not yet exist. This sits alongside the existing `.ai/research/`, `.ai/proposals/`, `.ai/pr_drafts/`, and `.ai/tmp/` directories used by this repo for AI-generated artifacts.

### 7. Validate Slice Markers (self-check)

Before handing back, prove the plan you just wrote can actually be sliced. Run the validator in inspect mode (it writes nothing):

```bash
python3 .claude/skills/plan-export/scripts/slice_impl_plan.py .ai/impl_plans/issue-$1.md --inspect
```

Read the exit code:

- **0** — the plan is sliceable. Proceed.
- **non-zero** — the validator prints exactly which marker is unbalanced, duplicated, out of order, or which content escaped a region. **Fix the markers in the plan file and re-run `--inspect` until it exits 0.** Never hand back a plan that fails this check.

### 8. Output and Control Transfer

After writing the plan file:

1. Confirm the file was created with the full path
2. Provide a brief summary of the phases
3. **Stop and wait for user instructions** — do NOT begin implementing the plan

Output format:

```text
Created implementation plan at [.ai/impl_plans/issue-$1.md](.ai/impl_plans/issue-$1.md)

Affected app(s): <app1>, <app2>
CHAIN_TYPE: <resolved>

The plan includes {N} phases:
1. [Phase 1 name]
2. [Phase 2 name]
...

Applicable guidelines that were incorporated:
- [List of rule files read]

Awaiting your instructions to proceed.
```

## Important Notes

- **Do NOT implement the plan** — only create the plan document.
- **Slice markers are mandatory.** Wrap preamble / each phase / final checklist in paired `<!-- impl-plan:begin slug="…" -->` … `<!-- impl-plan:end slug="…" -->` markers (see step 4) and confirm the plan passes the step-7 `--inspect` self-check before handing back.
- **Never read other plans.** This SKILL.md fully defines the format; opening another `.ai/impl_plans/` file only burns context and biases this plan toward another feature (see step 4).
- **Resolve `CHAIN_TYPE` once, up front** (step 2), and default to `default` unless the issue is genuinely chain-specific — don't infer a chain from an incidental mention.
- **Verification steps delegate, never shell out directly.** `compile-project`, `run-tests`, the `code-quality` agent, and the `dialyzer-reviewer` agent are the only sanctioned way to compile, test, format/lint, and type-check in this repo — a plan that tells the developer to run `mix test`/`mix format`/`mix credo`/`mix dialyzer` directly is wrong.
- The plan must be self-contained and not assume access to conversation history.
- **Only include phases with actual work** — do not create placeholder phases that say "no changes needed".
- **No code snippets** for functional changes or tests — explain WHAT and WHY instead.
- Point to existing files as pattern examples (e.g., "follow the pattern in `apps/explorer/lib/explorer/chain/cache/...`" or "follow the pattern in `apps/indexer/lib/indexer/fetcher/...`").
- **Do NOT prescribe documentation updates.** Inventing specific README/AGENTS edits leads to hallucinated prose. Plans should focus on code, tests, configuration, and migrations only.
- If the conversation lacks sufficient context, ask clarifying questions by using the AskUserQuestion tool before creating the plan.
- Each phase must have clear verification criteria so the developer knows when it's complete.
- In this repo, the easy-to-miss work is rarely the source edit itself — it's the wiring (`application.ex`/`supervisor.ex` registration, `router.ex` entries), the mode/chain-type helper piping from `AGENTS.md`, the OpenAPI schema + `generate-spec.sh` recompilation, the `background_migrations.ex` cache entry for heavy-index migrations, and `docker-compose/envs/common-blockscout.env` for any new environment variable (via the `update-common-blockscout-env` skill). Plans should call these out explicitly so they don't get silently dropped.
