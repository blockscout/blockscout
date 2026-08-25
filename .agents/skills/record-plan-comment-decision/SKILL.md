---
name: record-plan-comment-decision
description: "Save the decision made about a plan-review comment to its decision file."
disable-model-invocation: true
---

# Record Plan Comment Decision

Some sessions in this project exist for exactly one purpose: settle whether a single reviewer comment against an implementation plan (the kind of plan under `.ai/impl_plans/<issue-number>.md`) is valid, and if so, what to do about it. Such a session opens already knowing the plan path, the full comment text with its severity and slug, and the path to the sibling `.ai/impl_plans/<issue-number>/comments/<timestamp>/comments.md` where that slug is one of several recorded findings — sometimes also a scratchpad brief that originated the finding. The conversation that follows works through validity and the best resolution, occasionally weighing several real alternatives against each other, until a decision actually lands.

This skill runs at the end of that conversation, once the decision is settled, to write it down. It never runs on its own — it exists so the same "now persist what we decided" instruction doesn't have to be retyped by hand at the end of every one of these sessions.

## Before writing

Everything the file needs is already sitting in the conversation. Pull it together rather than asking for it again; only ask if something is genuinely missing from context.

The `<issue-number>` and `<timestamp>` come from the path to `comments.md` — the session's first message always states it, in the form `.ai/impl_plans/<issue-number>/comments/<timestamp>/comments.md`. Take both segments directly from that path; don't regenerate the timestamp (e.g. with `date`) and don't reuse one from a different comments round. The decisions file must land as a sibling of that exact `comments.md`, under its own `decisions/` directory, so a mismatched timestamp silently writes to the wrong round. The slug came with the comment itself, and the decision is what you and the user just agreed on.

Get the session's own id with a plain Bash call:

```bash
echo $CLAUDE_CODE_SESSION_ID
```

Earlier sessions of this same workflow had no way to learn their own session id and fell back to grepping a `sessions/mapping.tsv` file for a row matching their slug. That file may not exist, may not have the row yet, or may just not be there at all — `$CLAUDE_CODE_SESSION_ID` is always available in the shell and is the actual answer, so use it directly and skip the file search entirely.

## Writing the file

The target path is `.ai/impl_plans/<issue-number>/comments/<timestamp>/decisions/<slug>.md`. Create the `decisions/` directory first if needed, then write with a heredoc whose delimiter is quoted — `<<'EOF'`, not `<<EOF` — so the shell leaves every `$`, backtick, and quote in the Markdown alone:

```bash
mkdir -p .ai/impl_plans/<issue-number>/comments/<timestamp>/decisions && \
cat > .ai/impl_plans/<issue-number>/comments/<timestamp>/decisions/<slug>.md <<'EOF'
...
EOF
```

Write the content in English, even when the conversation that produced the decision happened in another language.

### Header

Every file opens with this block, in this order:

```markdown
# Decision: <slug>

- **Comment:** [comments.md](../comments.md) → `slug="<slug>"` (Severity: <severity>)
- **Scratchpad:** [brief.md](path/to/brief.md)
- **Plan:** [<plan-file>.md](path/to/plan/file.md) → <section/line(s) the decision touches>
- **Related decision:** [<other-slug>.md](<other-slug>.md) — <how it relates>
- **Session:** `<value from $CLAUDE_CODE_SESSION_ID>`
- **Status:** <short free-text status>
- **Date:** YYYY-MM-DD
```

Two of these lines are conditional, not decorative — include them only when they're actually true, and drop them otherwise:

- **Scratchpad** — only when a scratchpad brief actually exists for this finding.
- **Related decision** — only when this decision genuinely depends on, or is depended on by, another decision file in the same (or an earlier round's) `decisions/` directory. Most comments stand alone; don't invent a relationship to fill the line.

**Status** is a short free-text summary of where things stand, e.g. `accepted (valid Major, both parts); plan edits specified below, not yet applied to issue-14720.md` or `Accepted — plan edit specified, not yet applied`.

### Body

The body has no fixed shape, because the comments it records don't either — a Minor fixture-naming fix and a Blocker with three seriously-weighed alternatives shouldn't produce documents of the same shape. Write only the sections the conversation actually earned:

- **`## Decision`** — always. State the verdict plainly, and the concrete recommendation adopted if there is one.
- **`## Why it holds`** (or `## Why part 1 holds` / `## Why part 2 holds` for a comment with multiple parts) — always. Walk the evidence that was actually worked through.
- **`## Options considered`**, with a table of alternatives and a weighted rubric — only when the conversation seriously weighed multiple real alternatives (typically a Major/Blocker finding with a genuine design trade-off). Skip it entirely when the conversation only ever had one real path forward; a rubric invented after the fact to fill a section is worse than no section.
- **`## Why <winning option> is the best option`** — only alongside a rubric, explaining the choice and briefly addressing what was rejected and why.
- **`## Consequences to preserve during implementation`** — when the decision touches other in-flight work or existing plan text that must not regress under a later edit.

The test for all of it: this file transcribes a decision that was already reached, it doesn't reason its way to a new one. If a section wasn't discussed, it doesn't belong here.

## After writing

Reply with only the file path — no summary of what went in, no restating the decision. The point of writing it down is that it doesn't need to be said again.
