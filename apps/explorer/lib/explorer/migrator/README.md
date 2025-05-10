# Building Data Migrations with FillingMigration

This document describes how to implement modules using the `Explorer.Migrator.FillingMigration` behavior for data migration tasks in Blockscout.

## Overview

The `Explorer.Migrator.FillingMigration` provides a standardized framework for implementing **database migration processes** within Blockscout that:

- Process entities in batches with configurable batch sizes
- Execute operations in parallel with configurable concurrency
- Automatically persist migration progress to resume after interruptions
- Integrate with `Explorer.Chain.Cache.BackgroundMigrations` for status tracking

Migrations using this behavior are well-suited for:
- Updating data structure in existing database tables
- Normalizing relationships between entities
- Cleaning up corrupted or inconsistent database records
- Migrating data between tables or databases within Blockscout
- Backfilling computed fields
- One-time sanitization operations

> **Important:** `FillingMigration` is designed specifically for operations within the Blockscout database. While it may be tempting to fetch data from third-party sources (like RPC nodes) in the `last_unprocessed_identifiers` callback, this is not the intended use case. For data collection from external sources, use the `Indexer` application instead: a GenServer process or a `Indexer.BufferedTask` module. `FillingMigration` should focus on transforming and migrating data that's already been indexed.

## Core Concepts

When implementing `Explorer.Migrator.FillingMigration` both `use` and `alias` of the module are required:

```elixir
use Explorer.Migrator.FillingMigration
alias Explorer.Migrator.FillingMigration
```

### Required Callbacks

The key callbacks are must be implemented:

#### 1. migration_name/0

```elixir
@impl FillingMigration
def migration_name, do: "your_migration_name"
```

**Purpose**: Unique identifier for tracking migration progress in the `MigrationStatus` table.

#### 2. last_unprocessed_identifiers/1

```elixir
@impl FillingMigration
def last_unprocessed_identifiers(state) do
  limit = batch_size() * concurrency()
  
  ids = unprocessed_data_query()
        |> limit(^limit)
        |> Repo.all(timeout: :infinity)
  
  {ids, state}
end
```

**Purpose**: Retrieves entity identifiers for the next batch to process, managing state between calls, and controlling batch size.

#### 3. unprocessed_data_query/0

```elixir
@impl FillingMigration
def unprocessed_data_query do
  from(entity in Entity,
    where: entity.needs_processing == true,
    order_by: [asc: entity.id]
  )
end
```

**Purpose**: Defines the query to identify entities needing migration; may return `nil` when using custom identification logic.

#### 4. update_batch/1

```elixir
@impl FillingMigration
def update_batch(identifiers) do
  # Process the batch of identifiers
  Enum.each(identifiers, fn id ->
    process_entity(id)
  end)
  
  :ok
end
```

**Purpose**: Performs the actual migration work on a batch of entities, executed in parallel based on concurrency settings.

#### 5. update_cache/0

```elixir
@impl FillingMigration
def update_cache do
  BackgroundMigrations.set_your_migration_name_finished(true)
end
```

**Purpose**: Updates in-memory cache with migration completion status; called both on initial detection of completion and when all processing finishes.

## Migration Process Flow

1. The migration GenServer starts and checks if the migration is already completed
2. If not completed, it calls `before_start/0` and then begins batch processing
3. For each batch cycle:
   - `last_unprocessed_identifiers/1` retrieves the next batch of identifiers
   - The identifiers are split into chunks based on batch_size
   - Tasks are spawned to run `update_batch/1` on each chunk in parallel
   - The updated state is saved to the database
4. When no more identifiers are found, `on_finish/0` is called
5. The migration is marked as "completed" and `update_cache/0` is invoked
6. The GenServer terminates normally

## Configuration

### Setup Parameters

The `FillingMigration` behavior can be configured with the following key parameters:

1. **batch_size**: Number of entities to process in each batch (default: 500)
2. **concurrency**: Number of parallel tasks to execute (default: 4 * number of schedulers)
3. **timeout**: Delay between processing batches in milliseconds (default: 0)

### Adding to Application

To enable your migration module, update the following files:

#### 1. Configure Migration Enablement

There are two main approaches to enable your migration:

**For universal migrations** (should run on all instances):
Add your module to the "Background migrations" list in `apps/explorer/config/config.exs`:

```elixir
for migrator <- [
      # Background migrations
      Explorer.Migrator.TransactionsDenormalization,
      Explorer.Migrator.AddressCurrentTokenBalanceTokenType,
      # ... other migrations ...
      Explorer.Migrator.YourNewMigration  # Add your migration here
    ] do
  config :explorer, migrator, enabled: true
end
```

**For conditionally enabled or chain-specific migrations**:
Configure in `config/runtime.exs` using environment variables:

```elixir
config :explorer, Explorer.Migrator.YourNewMigration,
  enabled: ConfigHelper.parse_bool_env_var("MIGRATION_YOUR_NEW_MIGRATION_ENABLED", "true")
```

#### 2. Add to application.ex

Add your migration to the `configurable_children_set` list in `apps/explorer/lib/explorer/application.ex`:

```elixir
configurable_children_set =
  [
    # ... existing children
    configure(Explorer.Migrator.YourNewMigration),
    # ... other children
  ]
```

For chain-specific migrations, use `configure_chain_type_dependent_process` instead:

```elixir
configure_chain_type_dependent_process(Explorer.Migrator.YourChainSpecificMigration, :arbitrum)
```

#### 3. Add Configuration in runtime.exs

For additional configuration options, add to `config/runtime.exs`:

```elixir
config :explorer, Explorer.Migrator.YourNewMigration,
  enabled: ConfigHelper.parse_bool_env_var("MIGRATION_YOUR_NEW_MIGRATION_ENABLED", "true"),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_YOUR_NEW_MIGRATION_BATCH_SIZE", 500),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_YOUR_NEW_MIGRATION_CONCURRENCY", 10),
  timeout: ConfigHelper.parse_time_env_var("MIGRATION_YOUR_NEW_MIGRATION_TIMEOUT", "0s")
```

#### 4. Cache Configuration

If your migration needs cache integration, add a new key to `apps/explorer/lib/explorer/chain/cache/background_migrations.ex`:

```elixir
# Add the key to the MapCache
use Explorer.Chain.MapCache,
  # ... existing keys ...
  key: :your_new_migration_finished

# Add a fallback handler
defp handle_fallback(:your_new_migration_finished) do
  start_migration_status_task(
    YourNewMigration,
    &set_your_new_migration_finished/1
  )
end
```

## Advanced Usage

### Alternative Data Query Strategies

The `FillingMigration` behavior supports different approaches to identify and retrieve entities for processing:

#### 1. Nil/Empty Implementation

For migrations that don't use standard database filtering, you can implement a minimal `unprocessed_data_query/0`:

```elixir
@impl FillingMigration
def unprocessed_data_query, do: nil
```

This approach is useful when:
- Data comes from external sources
- Using specialized logic in `last_unprocessed_identifiers/1`, e.g., when the list of identifiers does not depend only on the results of query or it could be generated based on the migration state

#### 2. Calculated Identifiers Approach

Instead of querying the database, some migrations generate identifiers based on calculation or state:

```elixir
@impl FillingMigration
def last_unprocessed_identifiers(%{"current_position" => position} = state) do
  limit = batch_size() * concurrency()
  next_position = position + limit
  
  # Generate a sequence of identifiers based on position
  identifiers = Enum.to_list(position..(next_position - 1))
  
  # Update state with next position
  {identifiers, %{state | "current_position" => next_position}}
end

def last_unprocessed_identifiers(state) do
  # Initial state
  state = Map.put(state, "current_position", 0)
  last_unprocessed_identifiers(state)
end

@impl FillingMigration
def unprocessed_data_query, do: nil  # Not used with calculated identifiers
```

This approach is useful when:
- Processing sequential ranges (blocks, timestamps, IDs)
- Working with externally sourced identifiers
- Generating synthetic entities for testing or backfilling
- Implementing checkpointing based on position rather than database state

### State Management Between Calls

The `state` parameter in `last_unprocessed_identifiers/1` allows passing information between successive calls:

```elixir
@impl FillingMigration
def last_unprocessed_identifiers(state) do
  # Extract starting block from state, or initialize from database
  start_block = state[:current_block] || BlockNumber.get_max()
  end_block = max(start_block - 1000, 0)
  
  # Fetch identifiers for this block range using custom query logic
  ids = fetch_items_between_blocks(start_block, end_block)
  
  # Return identifiers and updated state with next block range
  {ids, Map.put(state, :current_block, end_block - 1)}
end

defp fetch_items_between_blocks(start_block, end_block) do
  # Custom logic to fetch or generate identifiers within block range
  # that doesn't fit well into unprocessed_data_query pattern
end
```

This state persistence allows migrations to resume exactly where they left off after interruptions, making them resilient to application restarts.

### Optimizing Batch Processing

Several techniques can be used to optimize batch processing:

#### 1. Using Transactions

Wrap operations in transactions for atomicity:

```elixir
@impl FillingMigration
def update_batch(identifiers) do
  Repo.transaction(fn ->
    # Perform multiple database operations atomically
    Repo.delete_all(from(entity in Entity, where: entity.id in ^ids_to_delete))
    Repo.update_all(from(entity in Entity, where: entity.id in ^ids_to_update), set: [status: "processed"])
    Repo.insert_all(TargetEntity, entities_to_insert)
  end)
end
```

#### 2. Bulk Operations with insert_all/delete_all/update_all

Use bulk operations for efficiency:

```elixir
@impl FillingMigration
def update_batch(data_keys) do
  # Prepare data for bulk insert
  records = Enum.map(data_keys, fn {key, value} ->
    %{
      key: key,
      value: value,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end)

  # Perform bulk insert with conflict resolution
  Repo.insert_all(
    TargetTable, 
    records, 
    conflict_target: [:key], 
    on_conflict: {:replace, [:value, :updated_at]},
    timeout: :infinity
  )
end
```

#### 3. Parallel Processing with Tasks

For complex operations, use Task for parallel processing:

```elixir
@impl FillingMigration
def update_batch(block_numbers) do
  # Fetch blocks in parallel
  blocks_task = Task.async(fn ->
    from(block in Block, where: block.number in ^block_numbers)
    |> preload([:miner])
    |> Repo.all(timeout: :infinity)
  end)

  # Fetch related transactions in parallel
  transactions_task = Task.async(fn ->
    from(tx in Transaction, where: tx.block_number in ^block_numbers)
    |> preload([:from_address, :to_address])
    |> Repo.all(timeout: :infinity)
  end)

  # Wait for all tasks to complete
  case Task.yield_many([blocks_task, transactions_task], :infinity) do
    [{_, {:ok, blocks}}, {_, {:ok, transactions}}] ->
      # Process results
      process_data(blocks, transactions)
    
    _ ->
      # Handle errors
      :error
  end
end
```

This approach is particularly valuable because:

- Database queries are I/O-bound rather than CPU-bound operations
- Parallel queries to different tables can significantly reduce total processing time
- Complex data relationships often require fetching from multiple sources that don't depend on each other
- Network requests and external API calls can run concurrently
- While one query is waiting on I/O, others can be executing

In the example above, fetching blocks and transactions can happen simultaneously since they're independent operations, potentially cutting processing time in half compared to sequential fetching.

### Implementing Lifecycle Callbacks

The `FillingMigration` behavior provides additional lifecycle callbacks:

#### 1. `on_finish`

Executes after all batches have been processed:

```elixir
@impl FillingMigration
def on_finish do
  # Delete all records from the source table since they've been processed
  from(source in SourceTable)
  |> Repo.delete_all(timeout: :infinity)
  
  :ok
end
```

This callback is ideal for:

- Cleanup operations after all entities are processed
- Removing source data that has been successfully migrated

#### 2. `before_start`

Executes before the migration begins processing any batches. This callback runs after the migration is marked as "started" but before the first batch processing begins.
This callback is useful for:

- Initializing any resources needed for the migration
- Preparing source data for more efficient processing
- Setting up preliminary conditions for the migration

The default implementation returns :ignore and the return value isn't evaluated, so this callback should be used primarily for side effects rather than critical path operations.
