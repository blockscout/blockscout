---
name: compile-project
description: "Compile the Blockscout Elixir project. Use this skill when you need to compile after code changes, recompile after switching CHAIN_TYPE or branches, initialize a freshly cloned project, or troubleshoot compilation errors. Trigger on 'compile', 'recompile', 'build the project', 'mix compile', 'initialize the project', 'first-time setup', or when compilation fails and you need to fix it."
---

# Compiling the Blockscout project

Blockscout is an Elixir umbrella project. `CHAIN_TYPE` is read at **compile time** and determines which Ecto repos and chain-specific modules are compiled in. Always set it before compiling.

The commands below show raw `mix` invocations — run them in whatever environment has Elixir available (host, devcontainer, CI, etc.).

## Standard compile

The safe default after editing code. Ensures deps and build tools are up to date before compiling — `deps.get` and `local.hex/rebar` are fast no-ops when nothing has changed, but protect against stale state from branch switches, other sessions, or interrupted builds:

```bash
CHAIN_TYPE=<type> mix do deps.get, local.hex --force, local.rebar --force, deps.compile, compile
```

## Full recompile

Required after switching `CHAIN_TYPE`, switching branches with dependency changes, or when incremental compilation produces stale-module errors. This cleans the project's own apps, re-fetches deps, and force-recompiles everything:

```bash
CHAIN_TYPE=<type> mix deps.clean block_scout_web ethereum_jsonrpc explorer indexer utils nft_media_handler && \
CHAIN_TYPE=<type> mix do deps.get, local.hex --force, local.rebar --force, deps.compile --force, compile
```

The app list above covers the standard Blockscout apps. If the project's `mix.exs` release config has changed, check `.devcontainer/bin/extract_apps.exs` — it can extract the current app list dynamically.

## First-time initialization

For a freshly cloned project (detectable by the absence of `apps/block_scout_web/priv/cert`):

```bash
CHAIN_TYPE=<type> mix do local.hex --force, local.rebar --force, deps.get, deps.compile, compile && \
cd apps/block_scout_web && mix phx.gen.cert blockscout blockscout.local && cd -
```

`local.hex` installs the Hex package manager, `local.rebar` installs Rebar (Erlang build tool) — both are needed before deps can be fetched. The `phx.gen.cert` step generates a self-signed SSL certificate needed by the Phoenix server. These only need to run once.

## CHAIN_TYPE

Valid values: `default`, `ethereum`, `arbitrum`, `optimism`, `polygon_zkevm`, `zksync`, `celo`, `rsk`, `stability`, `filecoin`, `scroll`, `zetachain`, `shibarium`, `suave`, `blackfort`, `mud`.

Omitting `CHAIN_TYPE` defaults to `default`. Note that `default` and `ethereum` are distinct — `ethereum` activates beacon/blob routes, EIP-4844 fields, and the Beacon Ecto repo that are absent under `default`.

If you're unsure which `CHAIN_TYPE` the project was last compiled with, a full recompile is the safest path.

## Troubleshooting

### Dependency lock mismatch

```
** (Mix) You have changed mix.exs but mix.lock is out of date
```

Run `mix deps.get` to update the lock file.

### Stale build artifacts

```
** (CompileError) cannot compile dependency
```

Clean and rebuild:

```bash
mix deps.clean --all
CHAIN_TYPE=<type> mix do deps.get, local.hex --force, local.rebar --force, deps.compile, compile
```

### Chain-type mismatch

```
** (UndefinedFunctionError) function SomeChainSpecificModule.some_function/1 is undefined
```

The project was compiled with a different `CHAIN_TYPE`. Do a full recompile with the correct value.

### Erlang/Elixir version mismatch

Check required versions in `mix.exs` and compare with `elixir --version`. The devcontainer has the correct versions pre-installed.

### Permission issues with Hex/Rebar

If `local.hex --force` or `local.rebar --force` fails with permission errors, fix ownership instead of using `sudo`:

```bash
chown -R $(whoami) ~/.mix ~/.hex
```

### Nothing else works

Nuclear option — clean everything and start fresh:

```bash
rm -rf _build deps
CHAIN_TYPE=<type> mix do deps.get, local.hex --force, local.rebar --force, deps.compile, compile
```

## Additional commands

```bash
# Check for unused dependencies
mix deps.unlock --unused

# View dependency tree
mix deps.tree

# Compile with warnings as errors (strict mode, use before PRs)
CHAIN_TYPE=<type> mix compile --warnings-as-errors
```

## When compilation warnings are acceptable

Some warnings are expected and do not need fixing:

- **Module redefinition warnings for ConfigHelper** — caused by `Code.eval_file()` in config loading; this is by design
- **TODO comments** — tracked technical debt, not compilation issues
- **Unused variables in generated code** — auto-generated functions may have unused params

New code should aim for zero warnings.
