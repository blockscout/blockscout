# Heavy Database Index Operations

This document describes the framework for managing heavy database index operations in Blockscout, particularly focusing on creating and dropping indexes on large tables.

## Overview

The modules under `Explorer.Migrator.HeavyDbIndexOperation` provide a standardized way to perform and track resource-intensive database index operations. These operations are particularly important for large tables like `logs`, `internal_transactions`, `token_transfers`, and `addresses` but are not limited to them.

## Operation Types

The framework supports two types of operations (`@operation_type`):

- `:create` - Creates a new index on a table
- `:drop` - Removes an existing index from a table

## Index Creation Methods

There are two approaches to define index creation:

### 1. Using `@query_string`

```elixir
@query_string """
CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS #{@index_name}
ON #{@table_name} (confirmation_id, block_number DESC)
WHERE confirmation_id IS NULL;
"""
```

This approach is preferred when:
- You need a partial index (with WHERE clause)
- You need to specify column order or sort direction (ASC/DESC)
- You need to combine multiple columns in a specific way
- You need fine-grained control over the index creation SQL
- You want to add custom index options or conditions

### 2. Using `@table_columns`

```elixir
@table_columns [:column1, :column2]
```

This approach is simpler and more suitable when:
- You're creating a straightforward index on one or more columns
- No special conditions or expressions are needed
- The index is not partial
- Default column ordering is acceptable

## Cache Management

The `update_cache/0` callback is used to maintain the in-memory cache of migration completion status.

### Empty Implementation

The `update_cache/0` callback can be empty when:
- The index operation doesn't affect runtime performance-critical operations
- Other parts of the system don't need to quickly check if this migration is complete
- The index is purely for maintenance or optimization purposes

### Non-Empty Implementation

You should implement `update_cache/0` when:
- The index is used in performance-critical queries
- Other system components need to quickly verify if the index exists
- The migration status affects the behavior of other operations

Example:
```elixir
def update_cache do
  BackgroundMigrations.set_heavy_indexes_create_logs_block_hash_index_finished(true)
end
```

## Creating a New Heavy Index Operation Module

1. Create a new module in `apps/explorer/lib/explorer/migrator/heavy_db_index_operation/`:
   ```elixir
   defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateYourNewIndex do
     use Explorer.Migrator.HeavyDbIndexOperation
     
     @table_name :your_table
     @index_name "your_index_name"
     @operation_type :create
     
     # Choose one approach:
     @table_columns [:column1, :column2]
     # or
     @query_string """
     CREATE INDEX ... 
     """
     
     # The rest of the module is implementation of callbacks described below
   end
   ```

2. Required Callbacks:

   All callbacks must be implemented in your module, but many of them can delegate to helper functions:

   Basic callbacks (usually just return module attributes):
   - `table_name/0` - Returns the table name (usually returns `@table_name`)
   - `operation_type/0` - Returns `:create` or `:drop` (usually returns `@operation_type`)
   - `index_name/0` - Returns the index name (usually returns `@index_name`)
   
   Operation-specific callbacks:
   - `dependent_from_migrations/0` - Returns list of migration names that must complete before this one
   - `update_cache/0` - Updates the in-memory cache when migration completes
   
   Helper-delegating callbacks:
   - `db_index_operation/0` - Executes the index creation/deletion. In most cases, enough to use `HeavyDbIndexOperationHelper.create_db_index/1` or `HeavyDbIndexOperationHelper.safely_drop_db_index/1`
   - `check_db_index_operation_progress/0` - Checks if operation is in progress. In most cases, enough to use `HeavyDbIndexOperationHelper.check_db_index_operation_progress/2`. In order to build the query string, you can use `HeavyDbIndexOperationHelper.create_index_query_string/3` or `HeavyDbIndexOperationHelper.drop_index_query_string/1`.
   - `db_index_operation_status/0` - Gets current operation status. In most cases, enough to use `HeavyDbIndexOperationHelper.db_index_creation_status/1` or `HeavyDbIndexOperationHelper.db_index_dropping_status/1`
   - `restart_db_index_operation/0` - Handles operation restart. In most cases, enough to use `HeavyDbIndexOperationHelper.safely_drop_db_index/1`
   - `running_other_heavy_migration_exists?/1` - Checks for conflicting migrations. In most cases, enough to use `MigrationStatus.running_other_heavy_migration_for_table_exists?/2`

## Configuration Updates

### 1. Application.ex

Add your module to the `configurable_children` list in `apps/explorer/lib/explorer/application.ex`:

```elixir
configure_mode_dependent_process(
  Explorer.Migrator.HeavyDbIndexOperation.YourNewIndex,
  :indexer
)
```

### 2. Config Files

The configuration approach depends on whether the index operation should run on all instances or only for specific chain types:

#### Universal Index Operations (config.exs)

If the index operation should run on all Blockscout instances regardless of chain type, add it to the list of index operations in `apps/explorer/config/config.exs`:

```elixir
for index_operation <- [
      # Heavy DB index operations
      Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockHashIndex,
      # ... other index operations ...
      Explorer.Migrator.HeavyDbIndexOperation.YourNewIndex  # Add your module here
    ] do
  config :explorer, index_operation, enabled: true
end
```

This is appropriate for indexes that are fundamental to Blockscout's operation, such as those on `logs`, `internal_transactions`, or `token_transfers` tables.

#### Chain-Specific Index Operations (runtime.exs)

If the index operation is specific to certain chain types (e.g., only for Arbitrum or only for Optimism), configure it in `config/runtime.exs`:

```elixir
# Example for an Arbitrum-specific index
config :explorer, Explorer.Migrator.HeavyDbIndexOperation.YourNewIndex,
  enabled: ConfigHelper.chain_type() == :some_chain_type
```

This approach allows you to:
- Enable indexes only for specific chain types
- Use runtime environment variables for configuration of index operation

## Setting Up Cache Tracking

1. Add a new key to the MapCache in `apps/explorer/lib/explorer/chain/cache/background_migrations.ex`:
```elixir
use Explorer.Chain.MapCache,
  # ... existing keys ...
  key: :heavy_indexes_your_new_index_finished
```

2. Add a fallback handler:
```elixir
defp handle_fallback(:heavy_indexes_your_new_index_finished) do
  start_migration_status_task(
    YourNewIndex,
    &set_heavy_indexes_your_new_index_finished/1
  )
end
```

3. The cache value can then be accessed:
```elixir
# Check status
BackgroundMigrations.heavy_indexes_your_new_index_finished?()
```

## Operation Flow and Status Updates

The heavy index operation follows a specific state flow managed by a GenServer:

1. Initial Flow:
   ```
   :continue -> :initiate_index_operation -> :check_if_db_operation_need_to_be_started -> :check_db_index_operation_progress
   ```

2. Operation Execution:
   - When conditions are met (no conflicting operations, all dependencies completed), `db_index_operation/0` is called
   - The next status check is scheduled using `check_interval` configuration (defaults to 10 minutes)

3. Status Updates:
   **Important Note:** Due to the default 10-minute check interval, there might be a delay between when an index operation actually completes and when its status is updated in the cache. For example, if an index creation takes only 1-2 seconds (common in new instances with empty databases), the cache will still not be updated for up to 10 minutes.

   Consider this when:
   - Implementing features that depend on index availability
   - Setting up development/testing environments
   - Configuring the check interval for your deployment needs

   You can adjust the check interval by setting the `MIGRATION_HEAVY_INDEX_OPERATIONS_CHECK_INTERVAL` environment variable.

## Best Practices

1. Consider dependencies between migrations carefully - ensure proper ordering of index operations when one depends on another.

2. Consider impact on Blockscout functionality:
   - Identify features that depend on the index being created
   - Implement appropriate handling for when the index is not yet available:
     ```elixir
     # Example of handling index-dependent functionality
     def fetch_data(params) do
       if BackgroundMigrations.heavy_indexes_your_new_index_finished?() do
         # Use optimized query that relies on the index
         fetch_with_index(params)
       else
         # Fallback behavior:
         # - Return limited/partial results
         # - Show "functionality temporarily unavailable" message
         # - Use alternative query path that doesn't require the index
         # - Return error with appropriate message
         handle_index_not_ready(params)
       end
     end
     ```
   - Consider adding index status checks to prevent:
     - Query timeouts
     - Excessive DB load from unindexed queries
     - Poor user experience
   - Document which features might be affected during index creation/deletion

3. Document index dependencies:
   - Which queries rely on this index
   - What performance impact to expect if the index is missing
   - Which features might need modification to handle index absence