---
name: fix-compilation
description: "Troubleshoot compilation failures in the Blockscout project. Use when compilation fails with environment, dependency, or configuration errors — not for simple code syntax fixes. Trigger on: 'stale build', 'cannot compile dependency', 'mix.lock out of date', 'chain-type mismatch', 'UndefinedFunctionError for chain module', compilation fails repeatedly, or when the compile-project skill's standard/full modes don't resolve the issue."
---

# Troubleshooting compilation failures

This skill provides a decision tree for resolving compilation failures that are not simple code fixes. For each error pattern, follow the recommended fix. Use the **compile-project** skill to recompile after applying a fix.

## Error patterns

### Dependency lock mismatch

```
** (Mix) You have changed mix.exs but mix.lock is out of date
```

**Fix:** Recompile with standard mode — it includes `deps.get` which updates the lock file.

### Stale build artifacts

```
** (CompileError) cannot compile dependency
```

**Fix:** Recompile with `full` mode. This cleans app builds and force-recompiles all dependencies.

### Chain-type mismatch

```
** (UndefinedFunctionError) function SomeChainSpecificModule.some_function/1 is undefined
```

**Fix:** The project was compiled with a different `CHAIN_TYPE`. Verify the correct value and recompile with `full` mode.

### Erlang/Elixir version mismatch

The required versions don't match the installed ones. Check `mix.exs` for required versions and compare with `elixir --version`. The devcontainer has the correct versions pre-installed.

### Permission issues with Hex/Rebar

`local.hex --force` or `local.rebar --force` fails with permission errors.

**Fix:** Fix ownership instead of using `sudo`:
```bash
chown -R $(whoami) ~/.mix ~/.hex
```

### Nuclear option

When nothing else works — clean everything and start fresh:
```bash
rm -rf _build deps
```
Then recompile with standard mode.

## Harmless warnings (safe to ignore)

- **Module redefinition for ConfigHelper** — caused by `Code.eval_file()` in config loading; by design
- **TODO comments** — tracked technical debt, not compilation issues
- **Unused variables in generated code** — auto-generated functions may have unused params

New code should aim for zero warnings.

<!-- 
  This skill is a placeholder for future compilation troubleshooting workflows.
  When you discover a new compilation failure pattern and its fix, add it here
  following the same format: error pattern → explanation → fix.
-->
