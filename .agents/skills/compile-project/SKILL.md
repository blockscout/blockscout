---
name: compile-project
description: "Compile the Blockscout Elixir project. Use this skill when you need to compile after code changes, recompile after switching CHAIN_TYPE or branches, initialize a freshly cloned project, or troubleshoot compilation errors. Trigger on 'compile', 'recompile', 'build the project', 'mix compile', 'initialize the project', 'first-time setup', or when compilation fails and you need to fix it."
---

# Compiling the Blockscout project

Spawn the **compiler-runner** agent. The agent runs compilation via a script that handles all environment setup automatically.

## How to invoke

Use the Agent tool with `subagent_type: "compiler-runner"`. Include `CHAIN_TYPE=<value>` and optionally the compilation mode in the prompt.

### Prompt examples

**Standard compile** (default — after code edits):
```
Compile. CHAIN_TYPE=arbitrum
```

**Full recompile** (after switching CHAIN_TYPE or branches with dependency changes):
```
Compile. CHAIN_TYPE=arbitrum. Mode: full
```

**First-time initialization** (fresh clone):
```
Compile. CHAIN_TYPE=arbitrum. Mode: init
```

## When to use which mode

- **standard** — default. Use after code edits. Runs `deps.get` + `compile`.
- **full** — use after switching `CHAIN_TYPE`, switching branches with dependency changes, or when standard compile fails with stale-module errors. Cleans app builds and force-recompiles all dependencies.
- **init** — use for first-time setup of a freshly cloned project. Installs Hex/Rebar, fetches deps, compiles, and generates SSL certificates. Detectable by absence of `apps/block_scout_web/priv/cert`.

The agent and script handle automatically:
- `CHAIN_TYPE` export
- `deps.get`, `local.hex --force`, `local.rebar --force`, `deps.compile`
- `deps.clean` and `--force` recompile (full mode)
- `phx.gen.cert` (init mode, skipped if cert already exists)
- Devcontainer delegation when mix is not available on the host

## CHAIN_TYPE

Chain-specific code compiles conditionally based on `CHAIN_TYPE`. Always set it to match the chain you're working on. Omitting `CHAIN_TYPE` defaults to `default`. Note that `default` and `ethereum` are distinct — `ethereum` activates beacon/blob routes and the Beacon Ecto repo.

If compilation fails with environment, dependency, or configuration errors that are not simple code fixes, use the **fix-compilation** skill for troubleshooting guidance.
