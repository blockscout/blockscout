---
name: alphabetically-ordered-aliases
description: Ensure that aliases are alphabetically ordered within their groups to maintain consistent code style and address Credo readability warnings.
---

## Overview

Elixir code style conventions prefer that module aliases are alphabetically ordered within their groups. This improves code readability, maintainability, and consistency. Credo checks for this ordering and warns when aliases are not properly alphabetized.

## When to Use

- When addressing Credo warning: "The alias is not alphabetically ordered among its group"
- When organizing module aliases at the top of a file
- When multiple aliases from related modules are defined together
- When refactoring code to improve consistency and readability

## Anti-Patterns (Avoid These)

```elixir
defmodule Explorer.Migrator.HeavyDbIndexOperation.RenameTransactions do
  # ❌ BAD: Aliases not alphabetically ordered
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper
  alias Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsIndex
  alias Explorer.Repo
end

# In the above, "Helper" comes after "DropTransactionsIndex" 
# alphabetically, but it's listed after it. Correct order should be:
# - DropTransactionsIndex (D < H)
# - Helper (H)
```

## Best Practices (Use These)

```elixir
defmodule Explorer.Migrator.HeavyDbIndexOperation.RenameTransactions do
  # ✅ GOOD: Aliases properly alphabetically ordered
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  
  # Within same group, ordered alphabetically:
  # C comes before H comes before R
  alias Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsIndex
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper
  alias Explorer.Repo
end
```

## How to Implement

### Step 1: Identify alias groups
Aliases are grouped by their module depth and prefix. List all aliases by location:

```
Group 1: Single-level modules
- alias Explorer.Repo

Group 2: Multi-level modules from same prefix
- alias Explorer.Chain.Cache.BackgroundMigrations
- alias Explorer.Migrator...
```

### Step 2: Sort alphabetically within each group

Within each group, sort by:
1. The full module path alphabetically
2. Consider the last component of the path when the prefix is the same

For modules with the same prefix like:
- `Explorer.Migrator.HeavyDbIndexOperation.CreateTransactions...`
- `Explorer.Migrator.HeavyDbIndexOperation.DropTransactions...`
- `Explorer.Migrator.HeavyDbIndexOperation.Helper`

Sort by the last component: `Create...` < `Drop...` < `Helper`

### Step 3: Reorder in code

Rearrange the alias statements to match the alphabetical order determined in Step 2.

### Step 4: Verify with Credo

Run Credo to ensure no warnings remain:

```bash
mix credo --strict
```

## Example Violations and Fixes

### Violation 1: Helper before DropTransactions

```elixir
# ❌ BEFORE
alias Explorer.Migrator.HeavyDbIndexOperation.Helper
alias Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsIndex

# ✅ AFTER
alias Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsIndex
alias Explorer.Migrator.HeavyDbIndexOperation.Helper
```

### Violation 2: Mixed ordering in group

```elixir
# ❌ BEFORE
alias Explorer.Repo
alias Explorer.Chain.Cache.BackgroundMigrations
alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}

# ✅ AFTER
alias Explorer.Chain.Cache.BackgroundMigrations
alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
alias Explorer.Repo
```

## Related Skills

- [Code Formatting](../code-formatting/SKILL.md) - Run after applying alias ordering fixes
- [Alias Nested Modules](../alias-nested-modules/SKILL.md) - Define aliases for nested modules

## References

- [Credo Readability.AliasOrder](https://hexdocs.pm/credo/Credo.Check.Readability.AliasOrder.html)
- [Elixir Style Guide - Aliases](https://hexdocs.pm/elixir/master/case-and-cond.html)
