#!/bin/bash
# PreToolUse hook: checks if Elixir tools exist on the host before running.
# If not found, blocks the command and tells Claude to use the devcontainer skill.
# Also intercepts `bs` commands — the `bs` script (.devcontainer/bin/bs) is a
# devcontainer-only helper and must always run inside the container.

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

# Check commands that require Elixir/Erlang tooling (including `bs` which wraps `mix`).
case "$COMMAND" in
  bs\ *|bs|mix\ *|mix|elixir\ *|elixir|iex\ *|iex|erl\ *|erl|rebar3\ *|rebar3)
    if ! command -v mix &>/dev/null; then
      BIN=$(echo "$COMMAND" | awk '{print $1}')
      echo "\"$BIN\" is not available — Elixir is not installed on this host. Use the devcontainer skill to run this command inside the container." >&2
      exit 2
    fi
    ;;
esac

exit 0
