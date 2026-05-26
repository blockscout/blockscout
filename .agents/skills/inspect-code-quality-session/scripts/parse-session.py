#!/usr/bin/env python3
"""
Parse a code-quality subagent JSONL session file and produce a structured
timeline with spec-compliance flags.

Usage:
    python3 parse-session.py <path-to-session.jsonl>

The output is plain text designed to be read by an LLM agent that will
write a narrative analysis from it.
"""

import json
import sys
import re
from datetime import datetime, timezone


def parse_timestamp(ts_str):
    """Parse ISO timestamp, return datetime."""
    if not ts_str:
        return None
    try:
        return datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None


def format_ts(ts_str):
    """Return just the HH:MM:SS portion of an ISO timestamp."""
    dt = parse_timestamp(ts_str)
    if dt:
        return dt.strftime("%H:%M:%S")
    return ts_str or "?"


def duration_between(start_str, end_str):
    """Human-readable duration between two ISO timestamps."""
    s = parse_timestamp(start_str)
    e = parse_timestamp(end_str)
    if not s or not e:
        return "?"
    delta = e - s
    total = int(delta.total_seconds())
    m, sec = divmod(total, 60)
    if m > 0:
        return f"{m}m {sec}s"
    return f"{sec}s"


def truncate(text, limit=600):
    """Truncate text to limit characters."""
    if not text:
        return ""
    text = str(text)
    if len(text) <= limit:
        return text
    return text[:limit] + f"\n... [truncated, {len(text)} chars total]"


def extract_exit_code(content_str):
    """Try to find 'Exit code N' at the start of tool result content."""
    if not content_str:
        return None
    m = re.match(r"Exit code (\d+)", str(content_str))
    if m:
        return int(m.group(1))
    return None


def extract_changed_files_count(content_str):
    """Extract CHANGED_FILES N from script output."""
    if not content_str:
        return None
    m = re.search(r"CHANGED_FILES (\d+)", str(content_str))
    if m:
        return int(m.group(1))
    return None


def extract_markers(content_str):
    """Find spec markers in script output."""
    if not content_str:
        return {}
    text = str(content_str)
    markers = {}
    for marker in [
        "FORMAT_RESULTS", "CREDO_RESULTS", "CSPELL_RESULTS",
        "ALL_PASS", "FORMAT_FAIL", "CREDO_FAIL", "CSPELL_FAIL",
        "CSPELL_SKIP", "NO_FILES",
    ]:
        markers[marker] = f"=== {marker} ===" in text or marker in text
    return markers


def get_content_text(content):
    """
    Extract text from message content, which can be a string or a list
    of content blocks.
    """
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict):
                if block.get("type") == "text":
                    parts.append(block.get("text", ""))
                elif block.get("type") == "tool_result":
                    c = block.get("content", "")
                    if isinstance(c, list):
                        for sub in c:
                            if isinstance(sub, dict) and sub.get("type") == "text":
                                parts.append(sub.get("text", ""))
                            else:
                                parts.append(str(sub))
                    else:
                        parts.append(str(c))
        return "\n".join(parts)
    return str(content)


def get_tool_uses(content):
    """Extract tool_use blocks from message content."""
    if not isinstance(content, list):
        return []
    return [b for b in content if isinstance(b, dict) and b.get("type") == "tool_use"]


def get_tool_results(content):
    """Extract tool_result blocks from message content."""
    if not isinstance(content, list):
        return []
    results = []
    for b in content:
        if isinstance(b, dict) and b.get("type") == "tool_result":
            results.append(b)
    return results


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 parse-session.py <path-to-session.jsonl>", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    try:
        with open(path) as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"ERROR: File not found: {path}", file=sys.stderr)
        sys.exit(1)

    records = []
    for i, line in enumerate(lines):
        line = line.strip()
        if not line:
            continue
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError as e:
            print(f"WARNING: Skipping malformed line {i + 1}: {e}", file=sys.stderr)

    if not records:
        print("ERROR: No valid records found in session file.", file=sys.stderr)
        sys.exit(1)

    # --- Metadata ---
    first = records[0]
    last = records[-1]
    agent_id = first.get("agentId", "?")
    branch = first.get("gitBranch", "?")
    session_id = first.get("sessionId", "?")
    start_ts = first.get("timestamp", "")
    end_ts = last.get("timestamp", "")

    # Find model from first assistant message
    model = "?"
    for r in records:
        if r.get("type") == "assistant":
            model = r.get("message", {}).get("model", "?")
            if model != "?":
                break

    print("=== SESSION METADATA ===")
    print(f"Agent ID: {agent_id}")
    print(f"Model: {model}")
    print(f"Branch: {branch}")
    print(f"Session ID: {session_id}")
    print(f"Start: {start_ts}")
    print(f"End: {end_ts}")
    print(f"Duration: {duration_between(start_ts, end_ts)}")
    print(f"JSONL lines: {len(records)}")
    print()

    # --- Extract initial prompt ---
    initial_prompt = ""
    chain_type = "?"
    if records and records[0].get("type") == "user":
        msg = records[0].get("message", {})
        initial_prompt = get_content_text(msg.get("content", ""))
        # Extract CHAIN_TYPE
        m = re.search(r"CHAIN_TYPE[=:]?\s*(\w+)", initial_prompt)
        if m:
            chain_type = m.group(1)

    print("=== INITIAL PROMPT ===")
    print(truncate(initial_prompt, 1000))
    print()
    print(f"=== CHAIN_TYPE: {chain_type} ===")
    print()

    # --- Build timeline by merging split messages ---
    # Assistant messages with the same message ID are split across lines
    # (streaming: first text, then tool_use). Merge them.
    timeline = []  # list of events
    seen_msg_ids = {}

    # Spec-compliance tracking
    compliance_flags = []
    quality_script_runs = 0
    tool_call_count = 0
    tool_calls_by_name = {}
    skill_invocations = []
    hook_blocks = []
    disallowed_tools_used = []
    first_script_exit_code = None
    recovery_attempted = False
    final_text = ""

    DISALLOWED_TOOLS = {"Edit", "Write", "Agent"}
    QUALITY_SCRIPT_PATTERN = r"code-quality-check\.sh"
    RECOVERY_COMMANDS = {"mix format", "mix credo", "cspell"}

    step_num = 0

    for rec in records[1:]:  # skip initial prompt (already printed)
        rec_type = rec.get("type")
        msg = rec.get("message", {})
        content = msg.get("content", "")
        ts = rec.get("timestamp", "")
        msg_id = msg.get("id", "")

        if rec_type == "assistant":
            # Check for text content
            text_parts = []
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict):
                        if block.get("type") == "text":
                            text_parts.append(block["text"])
                        elif block.get("type") == "tool_use":
                            tool_name = block.get("name", "?")
                            tool_input = block.get("input", {})
                            step_num += 1
                            tool_call_count += 1
                            tool_calls_by_name[tool_name] = tool_calls_by_name.get(tool_name, 0) + 1

                            # Check for disallowed tools
                            if tool_name in DISALLOWED_TOOLS:
                                disallowed_tools_used.append((step_num, tool_name))

                            # Build event description
                            event = f"[{step_num}] {format_ts(ts)} TOOL_CALL: {tool_name}\n"

                            if tool_name == "Bash":
                                cmd = tool_input.get("command", "?")
                                event += f"Command: {cmd}\n"

                                # Check if it's the quality script
                                if re.search(QUALITY_SCRIPT_PATTERN, cmd):
                                    quality_script_runs += 1
                                    if quality_script_runs > 1:
                                        compliance_flags.append(
                                            f"[!] SCRIPT_RERUN (step {step_num}): "
                                            f"Quality check script run again "
                                            f"(run #{quality_script_runs}). "
                                            f"This indicates a recovery/retry cycle."
                                        )

                                # Check for recovery commands
                                cmd_lower = cmd.lower().strip()
                                for rc in RECOVERY_COMMANDS:
                                    if rc in cmd_lower:
                                        recovery_attempted = True
                                        compliance_flags.append(
                                            f"[!] DIRECT_COMMAND (step {step_num}): "
                                            f"Agent ran '{cmd}' — "
                                            f"spec says not to attempt recovery."
                                        )

                                # Check if devcontainer exec runs a recovery command
                                if "devcontainer" in cmd or "exec.sh" in cmd:
                                    for rc in RECOVERY_COMMANDS:
                                        if rc in cmd_lower:
                                            recovery_attempted = True
                                            compliance_flags.append(
                                                f"[!] RECOVERY_VIA_CONTAINER (step {step_num}): "
                                                f"Agent ran '{rc}' inside devcontainer — "
                                                f"spec says not to attempt recovery."
                                            )

                            elif tool_name == "Skill":
                                skill_name = tool_input.get("skill", "?")
                                skill_args = tool_input.get("args", "")
                                skill_invocations.append((step_num, skill_name, skill_args))
                                event += f"Skill: {skill_name}"
                                if skill_args:
                                    event += f" (args: {skill_args})"
                                event += "\n"

                                if first_script_exit_code and first_script_exit_code != 0:
                                    compliance_flags.append(
                                        f"[!] SKILL_INVOCATION (step {step_num}): "
                                        f"Agent invoked '{skill_name}' skill — "
                                        f"not part of the prescribed workflow."
                                    )
                            else:
                                event += f"Input: {truncate(json.dumps(tool_input), 300)}\n"

                            timeline.append(event)

            # Print text if present (and not already a tool_use line)
            if text_parts:
                combined = " ".join(text_parts).strip()
                if combined:
                    final_text = combined  # track last text for final summary detection
                    step_num += 1
                    event = f"[{step_num}] {format_ts(ts)} ASSISTANT_TEXT\n"
                    event += f'"{truncate(combined, 400)}"\n'

                    # Check if this is a recovery decision
                    if first_script_exit_code and first_script_exit_code != 0:
                        lower = combined.lower()
                        recovery_phrases = [
                            "fix", "formatting", "let me",
                            "i'll run", "i need to"
                        ]
                        if any(p in lower for p in recovery_phrases):
                            if not any("RECOVERY_ATTEMPT" in f for f in compliance_flags):
                                compliance_flags.append(
                                    f"[!] RECOVERY_ATTEMPT (step {step_num}): "
                                    f"Agent decided to fix issues instead of "
                                    f"reporting failure and stopping. "
                                    f'Spec says: "report the raw script output '
                                    f'as an error and stop. Do NOT attempt to '
                                    f'recover."'
                                )

                    timeline.append(event)

        elif rec_type == "user":
            # Could be a tool_result or injected content (skill loading)
            tool_results = get_tool_results(content) if isinstance(content, list) else []

            if tool_results:
                for tr in tool_results:
                    step_num += 1
                    is_error = tr.get("is_error", False)
                    tr_content = tr.get("content", "")
                    if isinstance(tr_content, list):
                        tr_text = " ".join(
                            str(x.get("text", x)) if isinstance(x, dict) else str(x)
                            for x in tr_content
                        )
                    else:
                        tr_text = str(tr_content)

                    exit_code = extract_exit_code(tr_text)
                    changed_files = extract_changed_files_count(tr_text)
                    markers = extract_markers(tr_text)

                    # Track first script exit code
                    if exit_code is not None and first_script_exit_code is None:
                        first_script_exit_code = exit_code

                    event = f"[{step_num}] {format_ts(ts)} TOOL_RESULT"

                    if is_error:
                        event += " (ERROR)"
                        # Check for hook blocks
                        if "hook error" in tr_text.lower() or "hook" in tr_text.lower():
                            hook_blocks.append((step_num, tr_text))
                            compliance_flags.append(
                                f"[!] HOOK_BLOCK (step {step_num}): "
                                f"Command blocked by pre-tool-use hook."
                            )
                    if exit_code is not None:
                        event += f" (exit_code={exit_code})"
                    event += "\n"

                    if changed_files is not None:
                        event += f"Changed files: {changed_files}\n"

                    # Show active markers
                    active = [k for k, v in markers.items() if v]
                    if active:
                        event += f"Markers: {', '.join(active)}\n"

                    event += f"Content: {truncate(tr_text, 500)}\n"
                    timeline.append(event)

            else:
                # Injected content (e.g., skill instructions loading)
                text = get_content_text(content)
                if text and len(text) > 50:
                    step_num += 1
                    # Detect skill content injection
                    if "Base directory for this skill:" in text:
                        skill_match = re.search(r"skills/([^/\s]+)", text)
                        skill_name = skill_match.group(1) if skill_match else "?"
                        event = f"[{step_num}] {format_ts(ts)} SKILL_LOADED: {skill_name}\n"
                        event += f"Content: {truncate(text, 300)}\n"
                    else:
                        event = f"[{step_num}] {format_ts(ts)} INJECTED_CONTENT\n"
                        event += f"Content: {truncate(text, 300)}\n"
                    timeline.append(event)

    # --- Print timeline ---
    print("=== TIMELINE ===")
    print()
    for event in timeline:
        print(event)

    # --- Spec compliance summary ---
    # Add informational flags
    info_flags = []
    info_flags.append(f"[i] CHAIN_TYPE_EXTRACTED: {chain_type}")

    # Check script path correctness
    # (look for relative path usage in first script call)
    for event in timeline:
        if "code-quality-check.sh" in event:
            if ".agents/agents/scripts/code-quality-check.sh" in event:
                info_flags.append("[i] SCRIPT_PATH: Correct relative path used")
            elif "/" in event and "code-quality-check.sh" in event:
                info_flags.append("[!] SCRIPT_PATH: Absolute or incorrect path used")
            break

    # Check final summary format
    if final_text:
        has_format = "**Formatting:**" in final_text or "Formatting:" in final_text
        has_credo = "**Credo:**" in final_text or "Credo:" in final_text
        has_overall = "**Overall:**" in final_text or "Overall:" in final_text
        if has_format and has_credo and has_overall:
            info_flags.append("[i] FINAL_FORMAT: Output follows expected structured summary format")
        else:
            compliance_flags.append("[!] FINAL_FORMAT: Output does not match expected summary format")

    info_flags.append(f"[i] QUALITY_CHECK_RUNS: {quality_script_runs} (expected: 1)")

    print("=== SPEC COMPLIANCE ===")
    print()
    if not compliance_flags:
        print("[OK] No spec violations detected.")
    else:
        for flag in compliance_flags:
            print(flag)
            print()
    print()
    for flag in info_flags:
        print(flag)
    print()

    # --- Tool usage summary ---
    print("=== TOOL USAGE SUMMARY ===")
    for name, count in sorted(tool_calls_by_name.items()):
        extra = ""
        if name == "Skill" and skill_invocations:
            skills = [s[1] for s in skill_invocations]
            extra = f" ({', '.join(skills)})"
        print(f"{name}: {count} call(s){extra}")

    if disallowed_tools_used:
        print()
        print("DISALLOWED TOOLS USED:")
        for step, tool in disallowed_tools_used:
            print(f"  Step {step}: {tool}")
    else:
        print(f"\nDisallowed tools (Edit, Write, Agent): none used")
    print()

    # --- Final result (from last assistant text) ---
    print("=== FINAL AGENT OUTPUT ===")
    print(truncate(final_text, 800))
    print()


if __name__ == "__main__":
    main()
