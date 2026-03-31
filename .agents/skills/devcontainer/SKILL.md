---
name: devcontainer
description: "Invoke this skill immediately if the user's request contains any of these trigger phrases: 'devcontainer', 'in the container', 'inside the container', 'docker exec'. Also use when host execution is not viable: (1) mix/elixir/erlang is not found, (2) Elixir/OTP versions on host are incompatible with the project, or (3) a previous host command failed due to environment/tooling issues. Do not use this skill by default for routine mix/test/compile commands if they can run successfully on the host and the user did not mention the devcontainer."
allowed-tools: Bash(.claude/skills/devcontainer/scripts/exec.sh *)
---

# Run commands in devcontainer

Execute any command inside the project's devcontainer:

```
.claude/skills/devcontainer/scripts/exec.sh [--env-file PATH]... [-e KEY=VALUE]... <command> [args...]
```

**IMPORTANT**: Always use the relative path shown above — never an absolute path. This ensures the `allowed-tools` rule matches and no permission prompt is shown.

## Environment variables

Use `--env-file` and/or `-e` flags to pass environment variables into the container:

```bash
# Source an env file (path relative to project root)
.claude/skills/devcontainer/scripts/exec.sh --env-file tmp/arbitrum.env mix compile

# Quick one-off override
.claude/skills/devcontainer/scripts/exec.sh -e CHAIN_TYPE=arbitrum mix compile

# Combine: env file as baseline, -e to override specific vars
.claude/skills/devcontainer/scripts/exec.sh --env-file tmp/base.env -e CHAIN_TYPE=optimism mix test
```

- `--env-file` paths are relative to the project root (the bind mount).
- Multiple `--env-file` and `-e` flags are applied in order; `-e` overrides `--env-file`.
- When neither flag is given, the command runs with the container's bare environment.

Which variables are needed depends on the task — refer to the relevant skill (e.g., `run-tests` for testing, `run-server` for launching `mix phx.server`). For most compilation and code quality tasks, `-e CHAIN_TYPE=<type>` is sufficient.

## Notes

- The container workspace is a bind mount of the host project directory — file edits on the host are immediately visible inside the container and vice versa.
- For long-running commands, use `run_in_background: true` on the Bash tool call.
- If no container is running, the script exits with an error suggesting how to start one. Relay this to the user.
- For non-Elixir commands (e.g., `psql`, `git`), use `exec.sh` without env flags — they don't need the Blockscout environment.
