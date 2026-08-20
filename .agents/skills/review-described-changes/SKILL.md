---
name: review-described-changes
description: "Review a GitHub issue and a developer's described-changes overview. Compare the overview's claims against the actual code, then report gaps, inconsistencies, and mistakes. This skill does not change any files."
disable-model-invocation: true
---

# Review Described Changes

The **described changes** are a quick-and-dirty overview a developer wrote after discussing the problem — a rough sketch of what they intend to change. It is **not authoritative**. Approach it critically: read it skeptically, verify every claim against the actual code, and surface what is missing or wrong. The issue describes the real problem; the overview is just one person's first pass at a solution and will contain imprecision, missing files, and optimistic assumptions.

Your job is to read the issue, read the overview, open the code they reference, and report your critical assessment. **Do not modify any files** — this is read-only.

## Inputs

- **GitHub issue**: a number or full URL. A bare number resolves against the repo of the current working directory, so run this skill from inside the target repo.
- **Described changes**: the overview, pasted into the invocation.

If either input is missing from the invocation, ask for it before proceeding. Do not guess the issue number or invent the overview.

## Workflow

1. **Read the issue in full.** Prefer `gh`; if `gh` is unavailable, fetch the issue URL with whatever web-fetch capability the agent has:

   ```bash
   gh issue view <number-or-url> --comments
   ```

   `gh` resolves the repo from the git remote. If it cannot (no remote, or several), resolve the repo once and pass it explicitly:

   ```bash
   REPO=$(gh repo view --json owner,name -q '"\(.owner.login)/\(.name)"')
   ```

   then `gh issue view <number> --repo "$REPO" --comments`.

   Capture the actual problem, motivation, and any acceptance criteria the issue states.

2. **Read the described-changes overview carefully.** Extract the concrete claims: which files it says will change, which functions/symbols/configs it names, which tests/docs it mentions, and the approach it implies. Treat each claim as a hypothesis to verify, not a fact.

3. **Open the referenced code — do not reason from file names.** Read in full every file the overview and the issue point at, and use `rg` to locate the symbols they name:

   ```bash
   rg -n "function_in_overview|ENV_VAR|ClassName" -S .
   ```

   Broaden to obvious neighbors when it sharpens your judgment: where a new tool would be registered, the matching test module, the doc/spec section. The point is to ground your assessment in what the code actually does, not what the overview claims it does.

4. **Discover this repo's conventions, then cross-check the overview against them.** Do not assume which convention files exist — look first:

   ```bash
   ls AGENTS.md CLAUDE.md CONTRIBUTING.md .claude/rules/ .cursor/rules/ .github/instructions/ docs/ 2>/dev/null
   ```

   Read only what is relevant to the surfaces the overview touches: adding a component of the kind being added, testing, docs, versioning. If the repo carries no such files, or they say nothing about this surface, derive the convention from the code instead. Find the closest existing sibling of what is being added and read it together with its tests and its docs. `git log --oneline -- <sibling-file>`, then `git show <sha>` on the commit that introduced it, shows the full set of surfaces a complete change of this kind touches here. Either path gives you the same thing: what a *complete* change normally includes in this repo, which is how you spot what the overview omitted.

   Also check the repo's own skills directory (`.agents/skills/`, `.claude/skills/`, or wherever this repo keeps them) for one that states a mandatory action tied to the kind of surface the overview touches — e.g. a required migration mechanism for a specific category of schema change, a required companion file for new config values, a required spec update for API changes. These are often sharper than general docs, since each is written as a rule for one specific change shape rather than broad guidance. Skip skills that only reshape already-written code (naming, formatting, structural refactors, and other line-level style fixes) — a prose overview never specifies that level of detail, so there is nothing in it for those skills to check against.

5. **Reconcile and assess.** Square the issue, the overview, and the code you read, then report the problems below.

## What counts as an "obvious mistake"

A focused critical pass, not a deep audit:

- A referenced file, function, path, or symbol doesn't exist or is named differently in the code.
- A described change contradicts what the code actually does today.
- An obviously-required companion surface is missing, judged by how this repo does comparable changes — e.g. the new thing is never registered or exported where its peers are, or the doc that describes that surface is not updated. Ground this in the conventions or the sibling change from step 4, not in a generic checklist.
- **Test coverage is missing or wrong**: no unit tests for new logic, missing integration tests where real network behavior matters, or the testing approach itself is flawed — e.g. asserting against mocks in a way that never exercises the real logic, testing the wrong layer, or skipping error/negative paths. Judge this against the repo's own testing conventions and the idioms already present in its test suite — layout, fixtures, markers, and how integration tests are separated from unit tests.
- The proposed logic is simply wrong — it wouldn't actually solve the issue, or would break existing behavior.
- The overview is internally inconsistent.

Stay proportional. This is a rough overview, so when something is unclear rather than clearly wrong, raise it as an open question rather than asserting a defect. On versioning, mirror the project's existing neutrality: don't demand a version bump unless a repo rule, the issue, or the overview already calls for one.

## Output

Conversational, in the chat — no files created or changed. The issue and overview are already in context, so do **not** re-summarize them. Focus on your critical judgment:

### Do I agree with the described changes?
An honest overall read: agree / mostly agree with caveats / significant concerns — and why, in a few sentences.

### Gaps & inaccuracies
Bullets, each tied to the specific file, symbol, or rule that informs it. Distinguish what is clearly wrong from what you are only uncertain about (mark the latter as questions).

### Open questions for the author
Only questions whose answer would actually change the implementation — scope, approach, or whether a change is needed at all. First try to resolve each one yourself from the issue and the code; raise it here only if it genuinely can't be settled that way (intent, scope boundaries, decisions made elsewhere). Drop anything that's mere curiosity or wouldn't affect what gets built.

Close by reminding the user that this is a preliminary critique and that no files were changed — you have not started implementing.
