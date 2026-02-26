---
name: heavy-db-index-operation
description: Generate background migration modules for creating, dropping, or renaming database indexes on large tables using the Explorer.Migrator.HeavyDbIndexOperation framework. Automatically updates the BackgroundMigrations cache module with proper tracking. These migrations run in the background with progress tracking and dependency management. Use this skill for requests on creating background migrations to delete / create / rename indexes on large tables (logs, internal_transactions, token_transfers, addresses, transactions, blocks, etc.) to avoid blocking the database.
---

## Overview

The heavy-db-index-operation skill helps you generate migration modules that create, drop, or rename database indexes on large tables in a controlled, non-blocking manner. These operations use the `Explorer.Migrator.HeavyDbIndexOperation` behavior and are tracked via `Explorer.Migrator.MigrationStatus`.

**What this skill generates:**
1. Migration module files (create/drop/rename) in `apps/explorer/lib/explorer/migrator/heavy_db_index_operation/`
2. Updates to `apps/explorer/lib/explorer/chain/cache/background_migrations.ex`:
   - Cache keys for tracking completion status
   - Module aliases
   - Fallback handlers for cache population

## When to Use

- When creating new indexes on large tables (logs, internal_transactions, token_transfers, addresses, transactions, blocks, etc.)
- When dropping existing indexes as part of schema optimization
- When renaming indexes (typically as the final step in a create → drop → rename workflow)
- When the index operation might take significant time and should run in the background
- When you need to track the progress of index creation/deletion/rename
- When index operations need to depend on other completed migrations
- When you want CONCURRENT index operations on PostgreSQL

## Module Structure

Each heavy index operation module must implement the `Explorer.Migrator.HeavyDbIndexOperation` behavior with these callbacks:

### Required Callbacks

1. **`migration_name/0`** - Automatically generated from `operation_type` and `index_name`. Format: `heavy_indexes_{operation_type}_{lowercase_index_name}`
2. **`table_name/0`** - Returns the table atom (`:logs`, `:internal_transactions`, `:addresses`, etc.)
3. **`operation_type/0`** - Returns `:create`, `:drop`, or `:rename`
4. **`index_name/0`** - Returns the index name as a string (for renames, return the final/new index name)
5. **`dependent_from_migrations/0`** - Returns list of migration names this depends on (or `[]`)
6. **`db_index_operation/0`** - Executes the actual index creation/deletion/rename
7. **`check_db_index_operation_progress/0`** - Checks operation progress
8. **`db_index_operation_status/0`** - Returns operation status
9. **`restart_db_index_operation/0`** - Restarts the operation if needed
10. **`running_other_heavy_migration_exists?/1`** - Checks for conflicting migrations
11. **`update_cache/0`** - Updates the BackgroundMigrations cache when migration completes

## Index Definition Methods

### Method 1: Using `@table_columns` (Simple Indexes)

Use this for straightforward indexes on one or more columns:

```elixir
@table_columns ["address_hash", "block_number DESC", "index DESC"]

@impl HeavyDbIndexOperation
def db_index_operation do
  HeavyDbIndexOperationHelper.create_db_index(@index_name, @table_name, @table_columns)
end
```

**When to use:**
- Simple multi-column indexes
- No WHERE clause needed
- Standard column ordering acceptable
- Most common use case

### Method 2: Using `@query_string` (Complex Indexes)

Use this for more complex index definitions:

```elixir
@query_string """
CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
ON #{@table_name} ((1))
WHERE verified = true;
"""

@impl HeavyDbIndexOperation
def db_index_operation do
  HeavyDbIndexOperationHelper.create_db_index(@query_string)
end
```

**When to use:**
- Partial indexes (with WHERE clause)
- Expression indexes (e.g., `((1))` for existence check)
- Custom index types (GIN, GIST, etc.)
- Fine-grained control over SQL

## Naming Conventions

### Module Names

- **Creation**: `CreateTableNameColumnNameIndex`
  - Example: `CreateLogsAddressHashBlockNumberDescIndexDescIndex`
  - Example: `CreateAddressesVerifiedIndex`

- **Deletion**: `DropTableNameIndexName`
  - Example: `DropInternalTransactionsCreatedContractAddressHashPartialIndex`
  - Example: `DropLogsAddressHashIndex`

- **Renaming**: `RenameOldIndexNameToNewIndexName` or `RenameTableNameIndexDescriptor`
  - Example: `RenameTransactions2ndCreatedContractAddressHashWithPendingIndexA`

### Index Names

- Follow PostgreSQL naming: `table_name_column_name_suffix_index`
- For partial indexes: include `_partial` in the name
- For descending columns: include `_desc` in the name
- Examples:
  - `logs_address_hash_block_number_DESC_index_DESC_index`
  - `addresses_verified_index`
  - `internal_transactions_created_contract_address_hash_partial_index`

### File Names

- Convert module name to snake_case
- Example: `CreateLogsAddressHashIndex` → `create_logs_address_hash_index.ex`

## Dependencies via `dependent_from_migrations/0`

Specify migrations that must complete before this one runs:

```elixir
# No dependencies
@impl HeavyDbIndexOperation
def dependent_from_migrations, do: []

# Depends on another migration
alias Explorer.Migrator.EmptyInternalTransactionsData

@impl HeavyDbIndexOperation
def dependent_from_migrations do
  [EmptyInternalTransactionsData.migration_name()]
end

# Multiple dependencies
alias Explorer.Migrator.HeavyDbIndexOperation.{
  DropLogsIndexIndex,
  DropLogsBlockNumberAscIndexAscIndex
}

@impl HeavyDbIndexOperation
def dependent_from_migrations do
  [
    DropLogsIndexIndex.migration_name(),
    DropLogsBlockNumberAscIndexAscIndex.migration_name()
  ]
end
```

## Complete Example: Creating an Index

```elixir
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressHashBlockNumberDescIndexDescIndex do
  @moduledoc """
  Create B-tree index `logs_address_hash_block_number_DESC_index_DESC_index` on `logs` table 
  for (`address_hash`, `block_number DESC`, `index DESC`) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :logs
  @index_name "logs_address_hash_block_number_DESC_index_DESC_index"
  @operation_type :create
  @table_columns ["address_hash", "block_number DESC", "index DESC"]

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: []

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.create_db_index(@index_name, @table_name, @table_columns)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    operation = HeavyDbIndexOperationHelper.create_index_query_string(@index_name, @table_name, @table_columns)
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@index_name, operation)
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    HeavyDbIndexOperationHelper.db_index_creation_status(@index_name)
  end

  @impl HeavyDbIndexOperation
  def restart_db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_logs_address_hash_block_number_desc_index_desc_index_finished(
      true
    )
  end
end
```

## Complete Example: Dropping an Index

```elixir
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsCreatedContractAddressHashPartialIndex do
  @moduledoc """
  Drops index "internal_transactions_created_contract_address_hash_partial_index" on 
  internal_transactions(created_contract_address_hash, block_number DESC, transaction_index DESC, index DESC).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{EmptyInternalTransactionsData, HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :internal_transactions
  @index_name "internal_transactions_created_contract_address_hash_partial_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [EmptyInternalTransactionsData.migration_name()]
  end

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    operation = HeavyDbIndexOperationHelper.drop_index_query_string(@index_name)
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@index_name, operation)
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    HeavyDbIndexOperationHelper.db_index_dropping_status(@index_name)
  end

  @impl HeavyDbIndexOperation
  def restart_db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_internal_transactions_created_contract_address_hash_partial_index_finished(
      true
    )
  end
end
```

## Supported Table Names

Valid values for `@table_name` (from behavior typespec):

- `:addresses`
- `:address_coin_balances`
- `:address_current_token_balances`
- `:address_token_balances`
- `:blocks`
- `:internal_transactions`
- `:logs`
- `:token_transfers`
- `:tokens`
- `:transactions`

## File Location

All generated modules must be placed in:

```
apps/explorer/lib/explorer/migrator/heavy_db_index_operation/
```

## Required Aliases

Standard aliases to include:

```elixir
alias Explorer.Chain.Cache.BackgroundMigrations
alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper
```

For dependencies, add specific aliases:

```elixir
alias Explorer.Migrator.EmptyInternalTransactionsData
```

## Helper Functions Available

### For Index Creation:

- `HeavyDbIndexOperationHelper.create_db_index/1` - With query string
- `HeavyDbIndexOperationHelper.create_db_index/3` - With index name, table, columns
- `HeavyDbIndexOperationHelper.create_index_query_string/3` - Generate query string
- `HeavyDbIndexOperationHelper.db_index_creation_status/1` - Check creation status
- `HeavyDbIndexOperationHelper.add_concurrently_flag?/0` - For CONCURRENT keyword

### For Index Deletion:

- `HeavyDbIndexOperationHelper.safely_drop_db_index/1` - Drop with safety checks
- `HeavyDbIndexOperationHelper.drop_index_query_string/1` - Generate drop query
- `HeavyDbIndexOperationHelper.db_index_dropping_status/1` - Check dropping status

### Common:

- `HeavyDbIndexOperationHelper.check_db_index_operation_progress/2` - Monitor progress

## Cache Invalidation

When dropping indexes, you may need to invalidate caches as shown in the module docstring:

```elixir
@impl HeavyDbIndexOperation
def restart_db_index_operation do
  HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  BackgroundMigrations.invalidate_cache(__MODULE__.migration_name())
end
```

## Complete Example: Renaming an Index

For rename operations (typically used after create + drop to swap indexes):

```elixir
defmodule Explorer.Migrator.HeavyDbIndexOperation.RenameTransactions2ndCreatedContractAddressHashWithPendingIndexA do
  @moduledoc """
  Renames index "transactions_2nd_created_contract_address_hash_with_pending_index_a" 
  to "transactions_created_contract_address_hash_with_pending_index_a".
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper
  alias Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsCreatedContractAddressHashWithPendingIndexA
  alias Explorer.Repo

  @table_name :transactions
  @old_index_name "transactions_2nd_created_contract_address_hash_with_pending_index_a"
  @new_index_name "transactions_created_contract_address_hash_with_pending_index_a"
  @operation_type :rename

  # Note: migration_name will be:
  # "heavy_indexes_rename_transactions_created_contract_address_hash_with_pending_index_a"

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @new_index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [DropTransactionsCreatedContractAddressHashWithPendingIndexA.migration_name()]
  end

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  def db_index_operation do
    case Repo.query(rename_index_query_string(), [], timeout: :infinity) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to rename index from #{@old_index_name} to #{@new_index_name}: #{inspect(error)}")
        :error
    end
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@new_index_name, rename_index_query_string())
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    old_index_status = HeavyDbIndexOperationHelper.db_index_exists_and_valid?(@old_index_name)
    new_index_status = HeavyDbIndexOperationHelper.db_index_exists_and_valid?(@new_index_name)

    cond do
      # Rename completed: old index doesn't exist, new index exists and is valid
      old_index_status == %{exists?: false, valid?: nil} and new_index_status == %{exists?: true, valid?: true} ->
        :completed

      # Rename not started: old index exists, new index doesn't exist
      old_index_status == %{exists?: true, valid?: true} and new_index_status == %{exists?: false, valid?: nil} ->
        :not_initialized

      # Unknown state
      true ->
        :unknown
    end
  end

  @impl HeavyDbIndexOperation
  def restart_db_index_operation do
    # To restart, we need to rename back to the old name
    case Repo.query(reverse_rename_index_query_string(), [], timeout: :infinity) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to reverse rename index from #{@new_index_name} to #{@old_index_name}: #{inspect(error)}")
        :error
    end
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_rename_transactions_created_contract_address_hash_with_pending_index_a_finished(
      true
    )
  end

  defp rename_index_query_string do
    "ALTER INDEX #{@old_index_name} RENAME TO #{@new_index_name};"
  end

  defp reverse_rename_index_query_string do
    "ALTER INDEX #{@new_index_name} RENAME TO #{@old_index_name};"
  end
end
```

**When to use rename operations:**
- After creating a new index and dropping an old one
- To swap temporary index names with permanent ones
- Part of a create → drop → rename workflow for index replacement

**Important notes for rename operations:**
- Use `@operation_type :rename` (not `:create`)
- `index_name/0` should return the **new** (final) index name
- The migration name will be `heavy_indexes_rename_{new_index_name_lowercase}`
- Example: For `index_name` = "transactions_created_contract_address_hash_with_pending_index_a", the migration name is "heavy_indexes_rename_transactions_created_contract_address_hash_with_pending_index_a"

## Updating BackgroundMigrations Cache

After creating migration modules, you must update the cache tracking in 
`apps/explorer/lib/explorer/chain/cache/background_migrations.ex`:

### Step 1: Add Cache Keys

Add keys for each new migration at the top of the module:

```elixir
use Explorer.Chain.MapCache,
  name: :background_migrations_status,
  # ... existing keys ...
  key: :heavy_indexes_create_transactions_2nd_created_contract_address_hash_with_pending_index_a_finished,
  key: :heavy_indexes_drop_transactions_created_contract_address_hash_with_pending_index_a_finished,
  key: :heavy_indexes_rename_transactions_created_contract_address_hash_with_pending_index_a_finished
```

### Step 2: Add Module Aliases

Add aliases in the `HeavyDbIndexOperation` alias block:

```elixir
alias Explorer.Migrator.HeavyDbIndexOperation.{
  # ... existing aliases ...
  CreateTransactions2ndCreatedContractAddressHashWithPendingIndexA,
  DropTransactionsCreatedContractAddressHashWithPendingIndexA,
  RenameTransactions2ndCreatedContractAddressHashWithPendingIndexA
}
```

### Step 3: Add Fallback Handlers

Add `handle_fallback/1` functions for each migration:

```elixir
defp handle_fallback(:heavy_indexes_create_transactions_2nd_created_contract_address_hash_with_pending_index_a_finished) do
  set_and_return_migration_status(
    CreateTransactions2ndCreatedContractAddressHashWithPendingIndexA,
    &set_heavy_indexes_create_transactions_2nd_created_contract_address_hash_with_pending_index_a_finished/1
  )
end

defp handle_fallback(:heavy_indexes_drop_transactions_created_contract_address_hash_with_pending_index_a_finished) do
  set_and_return_migration_status(
    DropTransactionsCreatedContractAddressHashWithPendingIndexA,
    &set_heavy_indexes_drop_transactions_created_contract_address_hash_with_pending_index_a_finished/1
  )
end

defp handle_fallback(:heavy_indexes_rename_transactions_created_contract_address_hash_with_pending_index_a_finished) do
  set_and_return_migration_status(
    RenameTransactions2ndCreatedContractAddressHashWithPendingIndexA,
    &set_heavy_indexes_rename_transactions_created_contract_address_hash_with_pending_index_a_finished/1
  )
end
```

**Cache key naming convention:**
- Format: `heavy_indexes_{operation}_{snake_case_index_name}_finished`
- Operation: `create`, `drop`, `rename`, etc.
- Always ends with `_finished`

### Step 4: Add to Application Supervisor

Add each migration module to the application supervisor in 
`apps/explorer/lib/explorer/application.ex`:

Find the section with other heavy DB index operations and add:

```elixir
configure_mode_dependent_process(
  Explorer.Migrator.HeavyDbIndexOperation.CreateTransactions2ndCreatedContractAddressHashWithPendingIndexA,
  :indexer
),
configure_mode_dependent_process(
  Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsCreatedContractAddressHashWithPendingIndexA,
  :indexer
),
configure_mode_dependent_process(
  Explorer.Migrator.HeavyDbIndexOperation.RenameTransactions2ndCreatedContractAddressHashWithPendingIndexA,
  :indexer
),
```

**Important:** These entries must be added to start the migration processes during application startup.

## Update Cache Implementation

Each migration module must implement `update_cache/0`:

```elixir
@impl HeavyDbIndexOperation
def update_cache do
  BackgroundMigrations.set_heavy_indexes_create_my_index_finished(true)
end
```

The setter function name follows: `set_heavy_indexes_{operation}_{index_name}_finished/1`

## Checklist for New Modules

- [ ] Module name follows `Create*/Drop*/Rename*` convention
- [ ] File name is snake_case version of module name
- [ ] `@moduledoc` describes the index and its columns
- [ ] `use Explorer.Migrator.HeavyDbIndexOperation` declared near module top
- [ ] All required callbacks implemented
- [ ] `@table_name`, `@index_name`, `@operation_type` module attributes defined
- [ ] Index definition uses `@table_columns` OR `@query_string` (or custom for rename)
- [ ] Dependencies specified via `dependent_from_migrations/0`
- [ ] Proper aliases added at module top
- [ ] File saved in `apps/explorer/lib/explorer/migrator/heavy_db_index_operation/`
- [ ] `update_cache/0` implemented with correct setter name
- [ ] **BackgroundMigrations cache updated** with key, alias, and fallback handler
- [ ] **Application.ex updated** with `configure_mode_dependent_process` entry

## Common Pitfalls

❌ **Incorrect table name** - Must be one of the supported atoms  
❌ **Missing dependencies** - If index depends on other migrations, specify them  
❌ **Wrong helper function** - Use creation helpers for `:create`, dropping helpers for `:drop`  
❌ **Inconsistent naming** - Index name should match module name semantically  
❌ **Missing CONCURRENT** - Use `add_concurrently_flag?()` in query strings  
❌ **No progress tracking** - Always implement `check_db_index_operation_progress/0`  
❌ **Forgot cache updates** - Must update BackgroundMigrations cache module  
❌ **Missing update_cache/0** - Every module must implement this callback

## Workflow for Index Replacement (Create → Drop → Rename)

When replacing an existing index with a new version (e.g., adding a WHERE clause):

1. **Create** the new index with a temporary name (e.g., `_2nd_` prefix)
   - Depends on: latest heavy DB operation on the table
2. **Drop** the old index  
   - Depends on: the create operation completing
3. **Rename** the new index to the old index name
   - Depends on: the drop operation completing

This ensures zero downtime - the old index remains available until the new one is ready.

## References

- Behavior definition: [apps/explorer/lib/explorer/migrator/heavy_db_index_operation.ex](../../../apps/explorer/lib/explorer/migrator/heavy_db_index_operation.ex)
- README: [apps/explorer/lib/explorer/migrator/heavy_db_index_operation/README.md](../../../apps/explorer/lib/explorer/migrator/heavy_db_index_operation/README.md)
- Helper module: [apps/explorer/lib/explorer/migrator/heavy_db_index_operation/helper.ex](../../../apps/explorer/lib/explorer/migrator/heavy_db_index_operation/helper.ex)
