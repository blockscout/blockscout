---
name: code-formatting
description: Fixes code formatting in the Blockscout Elixir project using mix format. Use when you need to fix formatting violations, code style inconsistencies, or ensure consistent code formatting. For linting issues, use `mix credo`.
---

## Overview

The code-formatting skill ensures all Elixir code in the Blockscout project adheres to the project's code style guidelines using the Mix formatter. **Note:** `mix format` handles code formatting only; for linting and code quality issues, use `mix credo`.

Always run `mix format` after making any code changes in this repository.

## When to Use

- After making code changes (especially across multiple files)
- When addressing formatting violations or linting errors
- Before committing code to ensure consistency
- When working with modified files that may have formatting issues
- As part of the final preparation before creating a pull request

## How to Apply

Run the following command from the workspace root:

```bash
mix format
```

## What It Does

- Automatically formats all Elixir source files according to the project's `.formatter.exs` configuration
- Fixes indentation, spacing, and line length issues
- Ensures consistent code style across the codebase
- Makes no semantic changes to the code functionality
- Idempotent operation - safe to run multiple times
- **Does not address linting/code quality issues** - use `mix credo` for those

## Example Usage

After implementing changes to token transfer transformation:

```bash
mix format
```

This will format files like:
- `apps/indexer/lib/indexer/transform/token_transfers.ex`
- `apps/explorer/lib/explorer/chain/block.ex`
- Any other files with formatting issues

## Notes

- The formatter respects the project's `.formatter.exs` configuration file
- Some warnings about missing modules may appear but don't affect formatting
- The command is fast and can be run as part of your workflow
- Results are written directly to files, making changes in-place