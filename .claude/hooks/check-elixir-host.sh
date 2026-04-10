#!/bin/bash
# PreToolUse hook: checks if Elixir tools exist on the host before running.
# If not found, blocks the command and tells Claude to use the devcontainer skill.
# Also intercepts `bs` commands — the `bs` script (.devcontainer/bin/bs) is a
# devcontainer-only helper and must always run inside the container.

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

# Strip any leading VAR=VALUE environment assignments (e.g. CHAIN_TYPE=arbitrum mix ...)
# so that the case match works regardless of how many are prepended.
STRIPPED=$(printf '%s' "$COMMAND" | sed -E 's/^([A-Za-z_][A-Za-z_0-9]*=[^ ]+ )*//')

# Check commands that require Elixir/Erlang tooling (including `bs` which wraps `mix`).
case "$STRIPPED" in
  bs\ *|bs|mix\ *|mix|elixir\ *|elixir|iex\ *|iex|erl\ *|erl|rebar3\ *|rebar3)
    if ! command -v mix &>/dev/null; then
      BIN=$(echo "$STRIPPED" | awk '{print $1}')
      echo "\"$BIN\" is not available — Elixir is not installed on this host. Use the devcontainer skill to run this command inside the container." >&2
      exit 2
    fi
    ;;
esac

exit 0
