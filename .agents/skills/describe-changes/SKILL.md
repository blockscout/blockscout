---
name: describe-changes
description: "Write a short summary of the planned changes for a feature or issue, before you write any code."
disable-model-invocation: true
---

# Describe Changes Skill

This skill composes a concise description of the changes required to implement the feature or fix the issue discussed in the conversation, and saves it as a Markdown file under `.ai/pre-plan/`. The purpose is to confirm the agent's understanding of the scope and what files will be modified *before* touching any code.

## Purpose

When invoked, this skill generates a structured description of all changes needed to address the discussed issue/feature. This description serves as a confirmation that the agent:

1. **Understands the scope** of the changes
2. **Has actually read** all files that will be modified (not just guessed based on names)
3. **Can articulate** specific modifications at a high level

Saving it to a file (rather than only speaking it in chat) means the plan survives context compaction and can be reviewed, diffed against a later revision, or handed to another session.

## CRITICAL REQUIREMENT: File Reading Before Inclusion

**MANDATORY:** Before listing ANY file in the changes description, the agent that reports on it — a subagent doing the reading, or the invoking agent itself — MUST read that file first using the Read tool.

**Why this matters:**

- File names and project structure descriptions can be misleading
- Actual file contents reveal the true implementation details
- Reading ensures accurate understanding of what needs to change
- Guessing based on file names leads to incorrect or incomplete descriptions

**Verification checklist before including a file:**

- [ ] Did I (or the subagent I delegated to) read this file in the current conversation?
- [ ] Do I understand its current implementation?
- [ ] Can I describe the specific change needed?

**If a file has NOT been read, it MUST be read before including it in the description.**

## Workflow

### 1. Review Conversation Context

Identify from the conversation:

- The feature or issue being discussed
- Technical requirements and constraints
- Any implementation decisions already made
- Roughly which apps/areas are affected, and which files are likely in scope

If this isn't clear enough to scope the work, ask clarifying questions first instead of guessing.

### 2. Delegate the File-Reading to Subagents

Reading and understanding every candidate file is the expensive part of this skill (potentially many files, some large) — push it into subagents so the raw file contents don't pile up in your own context. For a small scope (a couple of files), it's simpler to just read them yourself and skip delegation entirely.

When delegating:

- **Write each subagent's task as fully self-contained.** State explicitly what feature/issue is being discussed and which files it must open — do not assume the subagent inherited this conversation's context. This makes the delegation work identically whether it actually runs as a context-sharing fork or as a fresh subagent with no memory of this conversation, so you don't need to branch your instructions on which one the harness gives you.
- Prefer `subagent_type: "fork"` when available (cheaper, shares your prompt cache). If the Agent call errors out because forking isn't available in the current harness, retry the same call without `subagent_type: "fork"` — the task text needs no changes, since it was already self-contained.
- Split the work by app or by area if it helps (e.g. one subagent for `apps/explorer` + migrations, one for `apps/block_scout_web` controllers/routes/tests) so the reads happen in parallel.
- Each subagent's job is narrow: read its assigned files and report back, per file, whether it needs to change and a one-sentence description of what and why — confirming it actually opened the file. It does **not** draft the final document, derive the slug/date, or write anything to disk — that stays with you (step 3 onward).

### 3. Assemble the Changes Description Yourself

Do this step yourself — do not delegate it, even when a fork is available. The synthesis is small (a handful of one-line bullets) and the failure modes of pushing it into a subagent (independently deriving the same slug, hitting the exact write path, reliably suppressing its own output) cost more in skill complexity than the context they'd save.

Using your own findings plus what the subagents reported, create a Markdown document with the following sections:

```markdown
## Changes Description

### Functional Changes

[List each file with a brief description of what will change]

- `apps/explorer/lib/explorer/module.ex`: [What will be modified and why]
- `apps/block_scout_web/lib/block_scout_web/controllers/api/v2/feature_controller.ex`: [What will be modified and why]

### Test Changes

[List test files that need to be created or modified]

- `apps/explorer/test/explorer/feature_test.exs`: [New tests or modifications needed]
- `apps/block_scout_web/test/block_scout_web/controllers/api/v2/feature_controller_test.exs`: [New tests or modifications needed]

### Configuration Changes

[List config files if applicable, or state "No configuration changes required"]

- `config/config.exs`: [What settings need adding or changing]
- `apps/explorer/config/config.exs`: [Per-app runtime config changes if applicable]

### Documentation & Project Artifacts

[List documentation and non-functional project files]

- `apps/explorer/priv/repo/migrations/<timestamp>_<name>.exs`: [Schema change if a migration is needed]
- `apps/block_scout_web/lib/block_scout_web/api_router.ex`: [Route additions]
- Other project files as applicable
```

### 4. Derive the Slug and Date

- Derive a short kebab-case slug (2-5 words) that summarizes the discussed feature/issue, the same way you'd name a branch — e.g. `add-withdrawal-fee-endpoint`, `fix-arbitrum-batch-gap`.
- Get today's date by actually running `date +%Y%m%d` (year, then month, then day — do not hand-compute or assume the format).

### 5. Write the File and Confirm

Write the Markdown document from step 3 to:

```
.ai/pre-plan/<slug>/changes-to-discuss-<YYYYMMDD>.md
```

using the slug and date from step 4 (create parent directories as needed). The file's content is exactly the `## Changes Description` document — no extra wrapper.

Do **not** paste the full changes description into the chat. Respond with only a brief confirmation: the file path, and a one-line count of files/sections touched, e.g.:

> Wrote `.ai/pre-plan/add-withdrawal-fee-endpoint/changes-to-discuss-20260819.md` (7 files across 4 sections).

If the user wants to see the content, they can open the file — printing it again in chat defeats the point of writing it out.

## Content Guidelines

### MUST INCLUDE

- **Functional Changes**: All source code files (`apps/*/lib/`) with specific modification descriptions
- **Test Changes**: Test files (`apps/*/test/`) that need creation or modification
- **Configuration Changes**: Root `config/*.exs` or per-app `apps/*/config/*.exs` files, or an explicit statement that none are needed
- **Documentation & Project Artifacts**: Migrations, router files (`api_router.ex`, `router.ex`), OpenAPI schemas, `mix.exs`, etc.

### MUST NOT INCLUDE

- **Problem Summary**: The conversation already contains this context
- **Verification Steps**: This is a pre-implementation description, not a test plan
- **Risk Assessment**: Not part of the scope confirmation

### Format Guidelines

- Use relative paths from the project root, e.g. `apps/explorer/lib/explorer/chain.ex`, not `explorer/lib/...` or an absolute path
- Keep descriptions concise (1 sentence per file)
- Group related files logically within each section
- If a section has no changes, explicitly state "No changes required" rather than omitting it

## Example Output

```markdown
## Changes Description

### Functional Changes

- `apps/explorer/lib/explorer/chain/withdrawal.ex`: Add a `fee` field to the withdrawal schema and its changeset
- `apps/explorer/lib/explorer/chain.ex`: Add a query function to fetch withdrawals with their computed fee
- `apps/block_scout_web/lib/block_scout_web/controllers/api/v2/withdrawal_controller.ex`: New action returning fee data for a withdrawal
- `apps/block_scout_web/lib/block_scout_web/api_router.ex`: Add the route for the new endpoint under the API v2 scope

### Test Changes

- `apps/explorer/test/explorer/chain_test.exs`: Unit tests covering fee computation and edge cases (zero fee, missing data)
- `apps/block_scout_web/test/block_scout_web/controllers/api/v2/withdrawal_controller_test.exs`: Controller tests for the new endpoint, including the not-found case

### Configuration Changes

- No configuration changes required

### Documentation & Project Artifacts

- `apps/explorer/priv/repo/migrations/20260819120000_add_fee_to_withdrawals.exs`: New migration adding the `fee` column to `withdrawals`
```

## Example Usage

When the user says:

```bash
/describe-changes
```

You should:

1. Review the conversation for the discussed feature/issue (ask first if it's unclear)
2. Delegate the reading of candidate files to one or more subagents with self-contained tasks (or read them yourself if the scope is small)
3. Assemble the structured changes description yourself from what came back
4. Derive the slug and date, then write the document to `.ai/pre-plan/<slug>/changes-to-discuss-<YYYYMMDD>.md`
5. Reply with only the file path and a one-line summary — not the full content

## Notes

- This skill is for **pre-implementation confirmation**, not post-implementation documentation
- If a file hasn't been read, read it (or have a subagent read it) before including it - do not guess
- If the conversation lacks sufficient context about what needs to change, ask clarifying questions first
- Focus on accuracy over completeness - it's better to read fewer files thoroughly than to guess about many
- Each invocation writes a new dated file under the same `<slug>/` directory, so re-running this skill later in the same discussion leaves the earlier version in place for comparison rather than overwriting it
- Only the file-reading step is delegated. Keep the assembly, slug/date derivation, and file write in your own turn — splitting those out too would require subagents to reliably hit an exact path and suppress their own output, for a context saving too small to be worth that fragility
