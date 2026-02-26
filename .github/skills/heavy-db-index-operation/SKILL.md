---
name: heavy-db-index-operation
description: Generate background migration modules for creating or dropping database indexes on large tables (logs, internal_transactions, token_transfers, addresses, etc.) using the Explorer.Migrator.HeavyDbIndexOperation framework. These migrations run in the background with progress tracking.
---

## Overview

The heavy-db-index-operation skill helps you generate migration modules that create or drop database indexes on large tables in a controlled, non-blocking manner. These operations use the `Explorer.Migrator.HeavyDbIndexOperation` behavior and are tracked via `Explorer.Migrator.MigrationStatus`.

## When to Use

- When creating new indexes on large tables (logs, internal_transactions, token_transfers, addresses, transactions, blocks, etc.)
- When dropping existing indexes as part of schema optimization
- When the index operation might take significant time and should run in the background
- When you need to track the progress of index creation/deletion
- When index operations need to depend on other completed migrations
- When you want CONCURRENT index operations on PostgreSQL

## Module Structure

Each heavy index operation module must implement the `Explorer.Migrator.HeavyDbIndexOperation` behavior with these callbacks:

### Required Callbacks

1. **`migration_name/0`** - Automatically generated from module name
2. **`table_name/0`** - Returns the table atom (`:logs`, `:internal_transactions`, `:addresses`, etc.)
3. **`operation_type/0`** - Returns `:create` or `:drop`
4. **`index_name/0`** - Returns the index name as a string
5. **`dependent_from_migrations/0`** - Returns list of migration names this depends on (or `[]`)
6. **`db_index_operation/0`** - Executes the actual index creation/deletion
7. **`check_db_index_operation_progress/0`** - Checks operation progress
8. **`db_index_operation_status/0`** - Returns operation status
9. **`restart_db_index_operation/0`** - Restarts the operation if needed
10. **`running_other_heavy_migration_exists?/1`** - Checks for conflicting migrations

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

  defimpl Enumerable do
    # Standard enumerable implementation...
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

  defimpl Enumerable do
    # Standard enumerable implementation...
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

## Checklist for New Modules

- [ ] Module name follows `Create*/Drop*` convention
- [ ] File name is snake_case version of module name
- [ ] `@moduledoc` describes the index and its columns
- [ ] All 10 callbacks implemented
- [ ] `@table_name`, `@index_name`, `@operation_type` module attributes defined
- [ ] Index definition uses `@table_columns` OR `@query_string`
- [ ] Dependencies specified via `dependent_from_migrations/0`
- [ ] Proper aliases added at module top
- [ ] File saved in `apps/explorer/lib/explorer/migrator/heavy_db_index_operation/`
- [ ] `Enumerable` protocol implemented (use existing examples as template)

## Common Pitfalls

❌ **Incorrect table name** - Must be one of the supported atoms
❌ **Missing dependencies** - If index depends on other migrations, specify them
❌ **Wrong helper function** - Use creation helpers for `:create`, dropping helpers for `:drop`
❌ **Inconsistent naming** - Index name should match module name semantically
❌ **Missing CONCURRENT** - Use `add_concurrently_flag?()` in query strings
❌ **No progress tracking** - Always implement `check_db_index_operation_progress/0`

## References

- Behavior definition: [apps/explorer/lib/explorer/migrator/heavy_db_index_operation.ex](../../../apps/explorer/lib/explorer/migrator/heavy_db_index_operation.ex)
- README: [apps/explorer/lib/explorer/migrator/heavy_db_index_operation/README.md](../../../apps/explorer/lib/explorer/migrator/heavy_db_index_operation/README.md)
- Helper module: [apps/explorer/lib/explorer/migrator/heavy_db_index_operation/helper.ex](../../../apps/explorer/lib/explorer/migrator/heavy_db_index_operation/helper.ex)
