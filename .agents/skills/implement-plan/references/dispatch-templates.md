# Dispatch templates

Exact text to pass each subagent. The plan has already been sliced into per-section files by `plan-export`'s slicer, `.agents/skills/plan-export/scripts/slice_impl_plan.py` (skill Step 1); you pass **paths**, never pasted content. Fill the `<...>` placeholders with the real slice directory, phase number, title, baseline SHA, resolved `CHAIN_TYPE`, and (on a gap round) the verifier's gap list. The slice files are the verbatim source of truth; your only job is to route paths. The subagents' output formats, environment know-how, and honesty rules live in their own agent files (`.agents/agents/`), not here.

`SLICE_DIR` below is the `.ai/tmp/impl/<plan-stem>/` directory reported in the slicer's manifest.

## Brief for `phase-developer` — first round

```
You are implementing ONE phase of an implementation plan. Implement only this phase.

Read these files first — they are the verbatim plan text and your source of truth:
- PLAN PREAMBLE (binds every phase: Overview, Applicable Guidelines, CHAIN_TYPE, any Ordering/Environment notes): <SLICE_DIR>/preamble.md
- YOUR TARGET PHASE (your only deliverable): <SLICE_DIR>/phase-<N>.md

OTHER PHASES (titles only, for resolving cross-references like "removed in Phase 5"):
<one line per other phase: "Phase K: <title>">

CHAIN_TYPE: <resolved value from the preamble> — pass this to compile-project, code-quality, and dialyzer-reviewer on every invocation; pass it to run-tests only if it is not `default`.

BASELINE: phases before this one are already implemented and committed on the current branch; the working tree reflects them. Build on top. Do NOT commit — the orchestrator commits after verification.
```

## Brief for `phase-developer` — gap round

Same as the first-round brief, with this appended:

```
VERIFIER GAP REPORT (close exactly these):
<the verifier's GAPS_FOUND list, verbatim>

Your prior work from the previous round is already in the working tree. Do not start over — address exactly the gaps above, then re-run the relevant checks.
```

## Brief for `plan-correspondence-verifier`

```
Verify that ONE phase was implemented completely and honestly. You are a correspondence checker, not a code reviewer.

Read these files first — they are the verbatim plan text:
- PLAN PREAMBLE (Overview, Applicable Guidelines, CHAIN_TYPE — how this repo and the affected app(s) are organized): <SLICE_DIR>/preamble.md
- PHASE UNDER VERIFICATION: <SLICE_DIR>/phase-<N>.md

CHAIN_TYPE: <resolved value from the preamble> — pass this to compile-project, code-quality, and dialyzer-reviewer on every invocation; pass it to run-tests only if it is not `default`.

BASELINE REF: judge only the changes between <baseline commit SHA — captured with `git rev-parse HEAD` before the first developer of this phase> and the current working tree. The phase's work is **uncommitted**: inspect it with `git diff <baseline>` (no `..`) plus `git status --porcelain` for new/untracked files. Do not use `git diff <baseline>..` — that compares two commits and shows nothing while the work is uncommitted. Note that this repo's `.ai/` tree is not gitignored, so `git status --porcelain` will also list the plan's own slice files under `.ai/tmp/impl/` — these are not part of the phase's work; ignore them.

DEVELOPER'S TEST EVIDENCE (for comparison — you independently re-run compile-project/run-tests/code-quality/dialyzer-reviewer yourself, so treat any mismatch against this block as a gap in its own right):
<the `### Test evidence` section of the developer's report, lifted verbatim — or "none" if the developer reported none>

Build your own checklist from the phase text, inspect the actual diff and files (not the developer's claims), independently re-invoke compile-project/run-tests/code-quality/dialyzer-reviewer yourself via your Skill/Agent access, and return your VERDICT in the structure your instructions define.
```

## Notes

- The plan slices live under `.ai/tmp/impl/<plan-stem>/`: `preamble.md`, `phase-1.md` … `phase-N.md`, `final-checklist.md`. This repo's `.ai/` tree is **not** gitignored (unlike bs-rust) — pass paths, never paste the content, and never sweep these files into a phase commit with `git add -A`/`git add .` (see the skill's Step 0.3 and Step 2.6).
- The phase titles for cross-references come from the slicer's manifest (its `title=` per slug).
- The **baseline ref** for the verifier is the SHA captured with `git rev-parse HEAD` *right before* dispatching the first developer for that phase — not after.
- The resolved **`CHAIN_TYPE`** comes from the plan preamble, resolved once by `plan-export` and never re-derived per phase. Both subagents thread it through every `compile-project`/`code-quality`/`dialyzer-reviewer` call, and through `run-tests` whenever it is not `default` (see `.claude/rules/chain-types.md`).
- Both subagents read the **same** `preamble.md` for the plan's Overview, Applicable Guidelines, and CHAIN_TYPE; each subagent's own honesty rules and environment/tooling instructions live in its agent file, not the preamble.
- The verifier's test-evidence block is the developer report's `### Test evidence` section, lifted **verbatim** (or "none") — it is runtime output, so it goes inline, not as a slice path. Lift it, don't summarize it, so "pass slices by reference, never paraphrase" still holds.
- Unlike bs-rust — where the verifier was deliberately tool-restricted (`Read, Grep, Glob, Bash` only, no `Agent`) and re-ran only fast non-DB-backed tests itself, trusting the developer's word for slow, gated DB-backed (`#[ignore]`) tests unless a phase's deliverable *was* such a test — this repo's tests all run through Ecto's SQL sandbox uniformly, so there is no cheap/expensive tier to split on. The verifier here carries `Skill`/`Agent` access precisely so it can reproduce the *entire* compile/test/quality/dialyzer sequence itself, every round, for every phase — there is no "authorize a re-run" add-on block to append, and no evidence-only fallback.
- For a **Final Checklist fix**, brief the developer with the failing checklist item plus the path to the most relevant slice (often the phase that item came from), and the instruction to fix only that item.
- If the plan had no markers and you fell back to slicing by headings yourself (skill Step 1, exit code 2), write the same filenames into the same `.ai/tmp/impl/<plan-stem>/` directory so these briefs work unchanged.
