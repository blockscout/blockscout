#!/usr/bin/env python3
"""
Parse a dialyzer-reviewer subagent JSONL session file and produce a structured
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


def extract_markers(content_str):
    """Find dialyzer spec markers in script output."""
    if not content_str:
        return {}
    text = str(content_str)
    markers = {}
    for marker in [
        "DIALYZER_RESULTS", "DIALYZER_CLEAN", "DIALYZER_WARNINGS",
        "ERROR",
    ]:
        markers[marker] = f"=== {marker} ===" in text or marker in text
    return markers


def extract_dialyzer_stats(content_str):
    """Extract 'Total errors: N, Skipped: N, Unnecessary Skips: N' from output."""
    if not content_str:
        return None
    m = re.search(
        r"Total errors:\s*(\d+),\s*Skipped:\s*(\d+),\s*Unnecessary Skips:\s*(\d+)",
        str(content_str),
    )
    if m:
        return {
            "total_errors": int(m.group(1)),
            "skipped": int(m.group(2)),
            "unnecessary_skips": int(m.group(3)),
        }
    return None


def extract_warning_count(content_str):
    """Count dialyzer warning lines in the output."""
    if not content_str:
        return 0
    text = str(content_str)
    # Count lines starting with "warning:" (dialyzer short format)
    return len(re.findall(r"^\s*warning:", text, re.MULTILINE))


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

    # --- Build timeline ---
    timeline = []
    compliance_flags = []
    dialyzer_script_runs = 0
    tool_call_count = 0
    tool_calls_by_name = {}
    hook_blocks = []
    disallowed_tools_used = []
    first_script_exit_code = None
    recovery_attempted = False
    final_text = ""
    dialyzer_stats = None
    found_markers = {}
    background_execution = False

    DISALLOWED_TOOLS = {"Edit", "Write", "Agent"}
    DIALYZER_SCRIPT_PATTERN = r"dialyzer-check\.sh"
    RECOVERY_COMMANDS = {"mix dialyzer"}

    step_num = 0

    for rec in records[1:]:
        rec_type = rec.get("type")
        msg = rec.get("message", {})
        content = msg.get("content", "")
        ts = rec.get("timestamp", "")

        if rec_type == "assistant":
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

                            if tool_name in DISALLOWED_TOOLS:
                                disallowed_tools_used.append((step_num, tool_name))

                            event = f"[{step_num}] {format_ts(ts)} TOOL_CALL: {tool_name}\n"

                            if tool_name == "Bash":
                                cmd = tool_input.get("command", "?")
                                event += f"Command: {cmd}\n"

                                if re.search(DIALYZER_SCRIPT_PATTERN, cmd):
                                    dialyzer_script_runs += 1
                                    # Check relative path
                                    if ".agents/agents/scripts/dialyzer-check.sh" in cmd:
                                        pass  # correct
                                    else:
                                        compliance_flags.append(
                                            f"[!] SCRIPT_PATH (step {step_num}): "
                                            f"Incorrect path used for dialyzer-check.sh. "
                                            f"Spec requires: .agents/agents/scripts/dialyzer-check.sh"
                                        )
                                    if dialyzer_script_runs > 1:
                                        compliance_flags.append(
                                            f"[!] SCRIPT_RERUN (step {step_num}): "
                                            f"Dialyzer script run again "
                                            f"(run #{dialyzer_script_runs}). "
                                            f"This indicates a recovery/retry cycle."
                                        )

                                # Check for recovery commands
                                cmd_lower = cmd.lower().strip()
                                for rc in RECOVERY_COMMANDS:
                                    if rc in cmd_lower and not re.search(DIALYZER_SCRIPT_PATTERN, cmd):
                                        recovery_attempted = True
                                        compliance_flags.append(
                                            f"[!] DIRECT_COMMAND (step {step_num}): "
                                            f"Agent ran '{cmd}' directly. "
                                            f'Spec says: "Do NOT attempt to recover by '
                                            f'running mix dialyzer or any other command '
                                            f'directly."'
                                        )

                                # Check devcontainer recovery
                                if ("devcontainer" in cmd or "exec.sh" in cmd) and not re.search(
                                    DIALYZER_SCRIPT_PATTERN, cmd
                                ):
                                    for rc in RECOVERY_COMMANDS:
                                        if rc in cmd_lower:
                                            recovery_attempted = True
                                            compliance_flags.append(
                                                f"[!] RECOVERY_VIA_CONTAINER (step {step_num}): "
                                                f"Agent ran '{rc}' inside devcontainer. "
                                                f"Spec says not to attempt recovery."
                                            )

                            else:
                                event += f"Input: {truncate(json.dumps(tool_input), 300)}\n"

                            timeline.append(event)

            if text_parts:
                combined = " ".join(text_parts).strip()
                if combined:
                    final_text = combined
                    step_num += 1
                    event = f"[{step_num}] {format_ts(ts)} ASSISTANT_TEXT\n"
                    event += f'"{truncate(combined, 400)}"\n'

                    # Check for recovery reasoning
                    if first_script_exit_code and first_script_exit_code != 0:
                        lower = combined.lower()
                        recovery_phrases = [
                            "fix", "let me", "i'll run", "i need to",
                            "try again", "retry",
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
                    markers = extract_markers(tr_text)
                    stats = extract_dialyzer_stats(tr_text)
                    warning_count = extract_warning_count(tr_text)

                    if exit_code is not None and first_script_exit_code is None:
                        first_script_exit_code = exit_code

                    if stats:
                        dialyzer_stats = stats

                    # Merge markers
                    for k, v in markers.items():
                        if v:
                            found_markers[k] = True

                    # Detect background execution
                    if "running in background" in tr_text.lower():
                        background_execution = True

                    event = f"[{step_num}] {format_ts(ts)} TOOL_RESULT"

                    if is_error:
                        event += " (ERROR)"
                        if "hook error" in tr_text.lower() or "hook" in tr_text.lower():
                            hook_blocks.append((step_num, tr_text))
                            compliance_flags.append(
                                f"[!] HOOK_BLOCK (step {step_num}): "
                                f"Command blocked by pre-tool-use hook."
                            )
                    if exit_code is not None:
                        event += f" (exit_code={exit_code})"
                    event += "\n"

                    if stats:
                        event += (
                            f"Dialyzer stats: total_errors={stats['total_errors']}, "
                            f"skipped={stats['skipped']}, "
                            f"unnecessary_skips={stats['unnecessary_skips']}\n"
                        )

                    if warning_count > 0:
                        event += f"Warning lines in output: {warning_count}\n"

                    active = [k for k, v in markers.items() if v]
                    if active:
                        event += f"Markers: {', '.join(active)}\n"

                    event += f"Content: {truncate(tr_text, 500)}\n"
                    timeline.append(event)

            else:
                text = get_content_text(content)
                if text and len(text) > 50:
                    step_num += 1
                    event = f"[{step_num}] {format_ts(ts)} INJECTED_CONTENT\n"
                    event += f"Content: {truncate(text, 300)}\n"
                    timeline.append(event)

    # --- Print timeline ---
    print("=== TIMELINE ===")
    print()
    for event in timeline:
        print(event)

    # --- Spec compliance summary ---
    info_flags = []
    info_flags.append(f"[i] CHAIN_TYPE_EXTRACTED: {chain_type}")

    if chain_type == "?":
        compliance_flags.append(
            "[!] CHAIN_TYPE_MISSING: No CHAIN_TYPE found in the initial prompt. "
            "Spec Step 1 requires it."
        )

    # Check script path
    for event in timeline:
        if "dialyzer-check.sh" in event:
            if ".agents/agents/scripts/dialyzer-check.sh" in event:
                info_flags.append("[i] SCRIPT_PATH: Correct relative path used")
            break

    # Check final summary format against DIALYZER_CLEAN/DIALYZER_WARNINGS rules
    if final_text:
        has_dialyzer_clean_response = "no warnings found" in final_text.lower()
        has_status = "**Status:**" in final_text
        has_warnings_count = "**Warnings:**" in final_text
        has_warnings_table = "| File |" in final_text or "| Warning |" in final_text

        if found_markers.get("DIALYZER_CLEAN"):
            if has_dialyzer_clean_response:
                info_flags.append(
                    "[i] FINAL_FORMAT: Agent correctly reported DIALYZER_CLEAN result"
                )
            else:
                compliance_flags.append(
                    "[!] FINAL_FORMAT: DIALYZER_CLEAN marker found but agent did not "
                    "report 'no warnings found' as required by spec"
                )
        elif found_markers.get("DIALYZER_WARNINGS"):
            if has_status and has_warnings_count:
                info_flags.append(
                    "[i] FINAL_FORMAT: Output follows expected structured summary format "
                    "for DIALYZER_WARNINGS"
                )
            else:
                missing = []
                if not has_status:
                    missing.append("**Status:**")
                if not has_warnings_count:
                    missing.append("**Warnings:**")
                if not has_warnings_table:
                    missing.append("Warnings table")
                compliance_flags.append(
                    f"[!] FINAL_FORMAT: Output missing expected fields: "
                    f"{', '.join(missing)}"
                )
        elif found_markers.get("ERROR"):
            info_flags.append("[i] SCRIPT_ERROR: Script reported an error")

    if background_execution:
        info_flags.append(
            "[i] BACKGROUND_EXECUTION: Script ran in background; "
            "agent used a second Bash call to retrieve output"
        )

    info_flags.append(f"[i] DIALYZER_SCRIPT_RUNS: {dialyzer_script_runs} (expected: 1)")

    if dialyzer_stats:
        info_flags.append(
            f"[i] DIALYZER_STATS: total_errors={dialyzer_stats['total_errors']}, "
            f"skipped={dialyzer_stats['skipped']}, "
            f"unnecessary_skips={dialyzer_stats['unnecessary_skips']}"
        )
        actionable = dialyzer_stats["total_errors"] - dialyzer_stats["skipped"]
        info_flags.append(f"[i] ACTIONABLE_ERRORS: {actionable}")

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
        print(f"{name}: {count} call(s)")

    if disallowed_tools_used:
        print()
        print("DISALLOWED TOOLS USED:")
        for step, tool in disallowed_tools_used:
            print(f"  Step {step}: {tool}")
    else:
        print(f"\nDisallowed tools (Edit, Write, Agent): none used")
    print()

    # --- Final result ---
    print("=== FINAL AGENT OUTPUT ===")
    print(truncate(final_text, 800))
    print()


if __name__ == "__main__":
    main()
