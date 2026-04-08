---
name: inspect-dialyzer-session
description: "Inspect and analyze a dialyzer-reviewer subagent session file (JSONL). Produces a step-by-step walkthrough of what the agent did, what each result was, why it chose its next action, and whether it followed the dialyzer-reviewer spec. Only invoke manually via /inspect-dialyzer-session <path-to-session.jsonl>."
disable-model-invocation: true
allowed-tools: Bash(python3 .agents/skills/inspect-dialyzer-session/scripts/parse-session.py *)
---

# Inspect dialyzer-reviewer session

Analyze a dialyzer-reviewer subagent JSONL session file to produce a
step-by-step narrative of what the agent did, the outcome of each action, and
whether the agent followed the dialyzer-reviewer spec.

## Inputs

The user provides the path to a `.jsonl` session file as the skill argument. If
no path is given, ask for it.

## Step 1 — Parse the session

Run the parser script with the session file path. The script extracts a
structured timeline, spec-compliance flags, and tool usage summary from the raw
JSONL.

```bash
python3 .agents/skills/inspect-dialyzer-session/scripts/parse-session.py "<session-file-path>"
```

**IMPORTANT**: Always use the relative path shown above.

If the script exits with non-zero or prints an ERROR line, report the error to
the user and stop.

## Step 2 — Read the dialyzer-reviewer agent spec

Read the agent definition so you can compare the agent's actual behavior
against its prescribed workflow:

```
.agents/agents/dialyzer-reviewer.md
```

The spec defines three steps the agent must follow:
1. Extract `CHAIN_TYPE` from the invoking prompt.
2. Run the dialyzer-check script (one specific Bash command).
3. Return a structured summary based on script output markers.

The spec also contains explicit prohibitions — most importantly:
> "Do NOT attempt to recover by running `mix dialyzer` or any other command
> directly."

## Step 3 — Write the analysis

Using the parser output and the spec, write a narrative analysis with these
sections:

### Report structure

Use this structure exactly:

```
## Session overview

One-paragraph summary: agent ID, model, branch, duration, and the high-level
outcome (passed on first try, failed and stopped, recovered then passed, etc.).

## Step-by-step walkthrough

For each numbered step from the TIMELINE section, write a subsection:

### Step N — <short title>

Explain:
- **What was done**: the action the agent took (tool call, text output, etc.)
- **Result**: what came back (exit code, markers, error, hook block, etc.)
- **Why the next step followed**: the reasoning that led the agent to its next
  action. Connect the result to the agent's stated reasoning (from its
  ASSISTANT_TEXT entries). Flag if the reasoning contradicts the spec.

Group closely related steps (e.g., an ASSISTANT_TEXT immediately followed by its
TOOL_CALL) into a single subsection when the text is just a preamble to the
tool call.

## Key observations

A markdown table summarizing notable findings:

| Issue | Detail |
|---|---|
| ... | ... |

Include rows for:
- Spec violations (from the [!] flags in SPEC COMPLIANCE)
- Hook enforcement events
- Disallowed tool usage (if any)
- Background execution adaptation (if the script ran in background)
- Dialyzer stats (total errors, skipped, actionable)
- Compiler warnings vs dialyzer warnings distinction
- Final result correctness (does the summary match the actual markers?)
- Any other notable behavior
```

### Writing guidelines

- Lead each step with what happened, not with judgment. State the fact, then
  note whether it aligns with the spec.
- Quote the spec when flagging a violation — show exactly which rule was broken.
- When the agent deviated from spec but the end result was correct, acknowledge
  both: the deviation and the successful outcome.
- Keep the tone analytical, not accusatory. The goal is understanding the
  agent's behavior, not assigning blame.
- Use the agent's own ASSISTANT_TEXT quotes to show its reasoning chain.
- Mention timestamps when they reveal something interesting (e.g., a 3-minute
  gap suggesting a long-running compilation/PLT rebuild inside the container).
- Distinguish compiler warnings from dialyzer warnings in the output — the
  script output often includes compile-time noise before the actual analysis.
