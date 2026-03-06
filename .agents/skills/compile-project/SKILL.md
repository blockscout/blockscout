---
name: compile-project
description: Compile the Blockscout Elixir project to verify all dependencies and code changes work correctly. Use this skill before finalizing changes to ensure the project builds successfully without errors.
---

## Overview

The compile-project skill ensures that all Elixir code, dependencies, and configurations in the Blockscout project compile successfully. This is a critical verification step before committing changes or submitting pull requests.

## When to Use

- **Before committing code changes** - Verify your changes don't break compilation
- **After modifying dependencies** - Ensure all deps resolve correctly
- **After significant refactoring** - Validate code structure changes
- **Before creating a pull request** - Final verification that everything builds
- **After pulling updates** - Ensure your local environment is in sync
- **When fixing compilation errors** - Iterative testing during debugging
- **After adding new modules or functions** - Verify project-wide compatibility

## How to Compile

Run the following command from the workspace root:

```bash
mix do deps.get, local.hex --force, local.rebar --force, deps.compile, compile
```

### Command Breakdown

1. **`mix do`** - Executes multiple Mix tasks in sequence
2. **`deps.get`** - Fetches all project dependencies from Hex and Git
3. **`local.hex --force`** - Installs/updates Hex (package manager), forcing reinstall
4. **`local.rebar --force`** - Installs/updates Rebar (Erlang build tool), forcing reinstall
5. **`deps.compile`** - Compiles all dependencies
6. **`compile`** - Compiles the project itself

### Dependencies-Only Compilation

If you only need to compile dependencies without the project code:

```bash
mix do deps.get, local.hex --force, local.rebar --force, deps.compile
```

## Example Usage

### After Making Code Changes

```bash
mix do deps.get, local.hex --force, local.rebar --force, deps.compile, compile
```

### Expected Output

Successful compilation will show:
```
* Getting dependencies...
* Compiling dependencies...
==> dependency_name
Compiling X files (.ex)
Generated dependency_name app
...
==> blockscout
Compiling X files (.ex)
Generated blockscout app
```

### Common Errors and Solutions

#### 1. Dependency Lock Mismatch
```
** (Mix) You have changed mix.exs but mix.lock is out of date
```
**Solution:**
```bash
mix deps.get
```

#### 2. Stale Build Artifacts
```
** (CompileError) cannot compile dependency
```
**Solution:**
```bash
mix deps.clean --all
mix do deps.get, local.hex --force, local.rebar --force, deps.compile, compile
```

#### 3. Compilation Warnings
```
warning: variable "foo" is unused
```
**Action:** Fix unused variables or prefix with underscore `_foo`

## Integration with Development Workflow

### Recommended Pre-Commit Checklist

1. ✅ Run `mix format` - Fix formatting issues
2. ✅ Run `mix do deps.get, local.hex --force, local.rebar --force, deps.compile, compile` - Verify compilation
3. ✅ Run `mix test` - Execute test suite (if applicable)
4. ✅ Run `mix credo` - Check code quality (if available)
5. ✅ Review git diff - Confirm changes are intentional
6. ✅ Commit and push

### Quick Verification After Changes

```bash
# Format, compile, and verify in one go
mix format && mix do deps.get, local.hex --force, local.rebar --force, deps.compile, compile
```

## Performance Notes

- **First compilation**: Can take several minutes (downloads and compiles all dependencies)
- **Incremental compilation**: Usually seconds to minutes (only changed files)
- **Clean compilation**: Use `mix clean` or `mix deps.clean --all` when needed
- **Parallel compilation**: Mix automatically uses available CPU cores

## When Compilation Warnings Are Acceptable

Some warnings may be acceptable in certain contexts:
- **TODO comments** - Tracked technical debt
- **Unused variables in generated code** - Auto-generated functions
- **Module redefinition warnings** - Configuration loading order (like ConfigHelper)

However, new code should aim for **zero warnings**.

## Troubleshooting

### Dependencies Won't Compile

```bash
# Nuclear option: clean everything and start fresh
rm -rf _build deps
mix do deps.get, local.hex --force, local.rebar --force, deps.compile, compile
```

### Erlang/Elixir Version Mismatch

Check required versions in `mix.exs`:
```elixir
def project do
  [
    elixir: "~> 1.19",
    # ...
  ]
end
```

Verify your versions:
```bash
elixir --version
```

### Permission Issues with Rebar

If `mix local.rebar --force` fails with permission errors, ensure proper ownership and permissions:

```bash
# Fix ownership of Mix home directory
chown -R $(whoami) ~/.mix ~/.hex $MIX_HOME $HEX_HOME 2>/dev/null || true

# Or explicitly set Mix/Hex home directories if needed
export MIX_HOME=~/.mix
export HEX_HOME=~/.hex

# Then try again
mix local.rebar --force
```

**Note:** Running Mix as root (with `sudo`) is **strongly discouraged** as it commonly causes permission/ownership issues in `_build`, `deps`, and `~/.mix`. It can also create security/operational risks. Use proper file ownership and environment variables instead.

## CI/CD Integration

This compilation step is typically part of the CI/CD pipeline. Ensure your changes pass locally before pushing to avoid CI failures.

## Related Skills

- **code-formatting** - Format code before compilation
- **compare-against-empty-list** - Fix performance issues that might surface during compilation

## Key Takeaways

- **Always compile before committing** - Catch errors early
- **Use the full command** - Ensures dependencies are up-to-date
- **Monitor compilation warnings** - They often indicate real issues
- **Clean builds when in doubt** - Removes stale artifacts
- **Compilation success ≠ correctness** - Still need tests and manual verification
- **Fast feedback loop** - Run frequently during development
- **Avoid running Mix as root** - Use proper permissions instead

## Additional Commands

### Check for unused dependencies
```bash
mix deps.unlock --unused
```

### View dependency tree
```bash
mix deps.tree
```

### Compile with warnings as errors (strict mode)
```bash
mix compile --warnings-as-errors
```
