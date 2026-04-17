---
name: ecto-migration
description: Generates Ecto migrations for the Blockscout Elixir project using mix ecto.gen.migration command. Use when you need to create database schema changes, add tables, modify columns, or manage database structure.
---

## Overview

The ecto-migration skill generates new Ecto migration files for the Blockscout project using the Mix task. Migrations are used to evolve the database schema over time in a versioned and controlled manner.

## When to Use

- When creating new database tables
- When modifying existing table structures (add/remove/change columns)
- When adding or removing database indexes
- When performing data migrations or transformations
- When implementing database constraints or relationships

## How to Apply

Run the following command from the workspace root:

```bash
mix ecto.gen.migration [migration_name] -r Explorer.Repo
```

Replace `[migration_name]` with a descriptive name for your migration using snake_case (e.g., `add_users_table`, `alter_transactions_status`).

## What It Does

- Creates a new migration file in `apps/explorer/priv/repo/migrations/` directory
- Generates a timestamped filename to ensure proper ordering
- Provides a basic migration template with `change/0` or `up/0` and `down/0` functions
- Targets the `Explorer.Repo` repository specifically

## Example Usage

Generate a migration to add a new column:

```bash
mix ecto.gen.migration add_metadata_to_blocks -r Explorer.Repo
```

This creates a file like:
- `apps/explorer/priv/repo/migrations/20260220123456_add_metadata_to_blocks.exs`

Then edit the generated file to implement your schema changes:

```elixir
defmodule Explorer.Repo.Migrations.AddMetadataToBlocks do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add :metadata, :jsonb
    end
  end
end
```

## Notes

- Always use descriptive migration names
- The `-r Explorer.Repo` flag specifies the repository (required for umbrella apps)
- Migration files are timestamped automatically to maintain order
- After creating a migration, edit it to implement the actual schema changes
- Run `mix ecto.migrate` to apply the migration to your database
- Use `mix ecto.rollback` to revert the last migration if needed
- For complex operations, consider using `up/0` and `down/0` instead of `change/0`
