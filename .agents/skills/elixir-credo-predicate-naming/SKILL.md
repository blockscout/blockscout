---
name: elixir-credo-predicate-naming
description: "Use when working on Elixir code with Credo predicate naming warnings, boolean helper functions, or renaming functions that start with is_. Prevents violations like: Predicate function names should not start with 'is' and should end in a question mark."
---

# Elixir Credo Predicate Naming

Use this skill to prevent and fix predicate naming violations in Elixir.

## Rules

- Predicate functions must end with `?`.
- Predicate functions must not start with `is_`.
- Prefer names like `valid_*?`, `enabled_*?`, `has_*?`, `can_*?`, `matches_*?`, or `<noun>_*?`.

## Refactor Workflow

1. Find predicate functions named like `is_*?`.
2. Rename each one to a Credo-compliant name that still reads clearly.
3. Update all call sites in the same module and across the codebase.
4. Keep arity unchanged unless behavior intentionally changes.
5. Run a focused Credo check for edited files.

## Naming Guidance

- `is_valid_zrc2_transfer_log?/4` -> `valid_zrc2_transfer_log?/4`
- `is_enabled?/1` -> `enabled?/1`
- `is_erc20_transfer?/2` -> `erc20_transfer?/2`
- `is_contract_verified?/1` -> `contract_verified?/1`

## Safety Checks

- Preserve semantics during rename.
- Verify no stale references remain.
- If the function is part of a public API, rename consistently and update docs/specs.

## Verification Commands

```bash
mix credo path/to/file.ex
mix test
```

## Expected Result

No Credo findings for predicate naming in updated files.
