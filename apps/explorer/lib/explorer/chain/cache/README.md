# In-Memory Caches

This document describes the framework for implementing efficient, configurable in-memory caches in Blockscout using the `Explorer.Chain.MapCache` behavior.

## Overview

The `Explorer.Chain.MapCache` provides a standardized way to implement and interact with cache objects in Blockscout. It uses `ConCache` under the hood to create and manage cache instances with configurable parameters like TTL (Time-to-Live), automatic cache invalidation, and more.

## Creating a New Cache Module

### 1. Basic Implementation

Create a new module in `apps/explorer/lib/explorer/chain/cache/`:

```elixir
defmodule Explorer.Chain.Cache.YourNewCache do
  use Explorer.Chain.MapCache,
    name: :your_cache_name,
    key: :primary_key
    # Add additional keys if needed, or use `keys: [:key1, :key2]` 
    # Additional ConCache options can be specified here
end
```

This minimal implementation is sufficient if the cache values will be set manually using `set/2` or `set_primary_key/1`. The default `handle_fallback/1` implementation will return `nil` for any cache miss, which is appropriate when there's no automatic way to fetch a value.

For example, `apps/explorer/lib/explorer/chain/cache/latest_l1_block_number.ex` uses this approach:

```elixir
defmodule Explorer.Chain.Cache.LatestL1BlockNumber do
  use Explorer.Chain.MapCache,
    name: :latest_l1_block_number,
    key: :block_number,
    ttl_check_interval: :timer.seconds(5),
    global_ttl: :timer.seconds(15)

  defp handle_fallback(_key), do: {:return, nil}
end
```

In this case, the cache is designed to be explicitly updated by external processes when new L1 block numbers are detected, with time-based expiration configured.

### 2. Adding Fallback Logic

To handle cache misses with automatic value fetching, implement the `handle_fallback/1` callback:

```elixir
defmodule Explorer.Chain.Cache.YourNewCache do
  use Explorer.Chain.MapCache,
    name: :your_cache_name,
    key: :primary_key,
    ttl_check_interval: :timer.seconds(30),  # Check for expired entries every 30 seconds
    global_ttl: :timer.minutes(5)            # All entries expire after 5 minutes

  # Called when the cache doesn't have a value for the requested key
  defp handle_fallback(:primary_key) do
    case fetch_data_from_source() do
      {:ok, value} ->
        # Cache the value and return it
        {:update, value}
      
      {:error, reason} ->        
        # Return a default value without caching it
        {:return, nil}
    end
  end
  
  # Fall through for any unexpected keys
  defp handle_fallback(_key), do: {:return, nil}
  
  # Your helper functions
  defp fetch_data_from_source do
    # Implement the logic to fetch data from the source
    # (database, external API, etc.)
  end
end
```

This implementation is useful when values can be automatically fetched from a source when needed. With expiration settings (`ttl_check_interval` and `global_ttl`), the fallback will be called periodically to refresh the data.

For example, `apps/explorer/lib/explorer/chain/cache/chain_id.ex` uses this approach:

```elixir
defmodule Explorer.Chain.Cache.ChainId do
  require Logger

  use Explorer.Chain.MapCache,
    name: :chain_id,
    key: :id

  defp handle_fallback(:id) do
    case EthereumJSONRPC.fetch_chain_id(Application.get_env(:explorer, :json_rpc_named_arguments)) do
      {:ok, value} ->
        {:update, value}

      {:error, reason} ->
        Logger.debug([
          "Couldn't fetch eth_chainId, reason: #{inspect(reason)}"
        ])

        {:return, nil}
    end
  end

  defp handle_fallback(_key), do: {:return, nil}
end
```

See the "Understanding TTL and Expiry" section for more details on how expiration parameters work.

### 3. Adding Custom Update Logic

To customize how the cache is updated, implement the `handle_update/3` callback:

```elixir
defmodule Explorer.Chain.Cache.YourNewCache do
  # ... previous code ...

  # Handle updates to the cache
  def handle_update(_key, nil, value), do: {:ok, value}
  
  # Example: For a numeric value, take the maximum when updating
  def handle_update(:primary_key, old_value, new_value), do: {:ok, max(new_value, old_value)}
  
  # ... other code ...
end
```

When the fallback returns `{:update, value}` or when `update/2` is called manually, the `handle_update/3` callback is invoked to determine how the cache value should be modified. The default implementation simply replaces the old value with the new one, but you can customize this logic for special cases.

For example, `apps/explorer/lib/explorer/chain/cache/block_number.ex` uses custom update logic to always keep the min and max block numbers:

```elixir
defmodule Explorer.Chain.Cache.BlockNumber do
  # ... other code ...

  def handle_update(_key, nil, value), do: {:ok, value}

  def handle_update(:min, old_value, new_value), do: {:ok, min(new_value, old_value)}

  def handle_update(:max, old_value, new_value), do: {:ok, max(new_value, old_value)}
  
  # ... other code ...
end
```

This ensures that:
1. For the `:min` key, we always store the smallest block number encountered
2. For the `:max` key, we always store the largest block number encountered
3. When there's no previous value (`nil`), we store the new value regardless

This pattern is particularly useful when implementing aggregate-style caches or when you need to enforce business rules about what values can be stored.

## Configuration

### 1. Add to Application Children

To start your cache when the application starts, add it to the appropriate list in `apps/explorer/lib/explorer/application.ex`. There are several approaches depending on your requirements:

#### Basic Configuration (Always Start)

For essential caches that should always start regardless of configuration:

```elixir
# In apps/explorer/lib/explorer/application.ex
base_children = [
  # ... existing children
  Explorer.Chain.Cache.YourNewCache,
  # ... other children
]
```

#### Configurable Caches (Can Be Enabled/Disabled)

For caches that can be enabled/disabled via configuration, use the `configure` helper function:

```elixir
# In apps/explorer/lib/explorer/application.ex
configurable_children = [
  # ... existing children
  configure(Explorer.Chain.Cache.YourNewCache),
  # ... other children
]
```

This pattern checks if the cache is enabled in the configuration before adding it to the children list. If the cache is disabled, it won't be started.

#### Chain-Type Dependent Caches

For caches that should only start on specific blockchain types, use the `configure_chain_type_dependent_process` helper:

```elixir
# In apps/explorer/lib/explorer/application.ex
configurable_children = [
  # For a single chain type
  configure_chain_type_dependent_process(Explorer.Chain.Cache.YourChainSpecificCache, :ethereum),
  
  # For multiple chain types
  configure_chain_type_dependent_process(Explorer.Chain.Cache.AnotherSpecificCache, [:optimism, :arbitrum]),
]
```

This approach checks the configured chain type and only starts the cache if it matches the specified type(s).

### 2. Add Configuration in Config Files

#### Universal Cache Configuration

For caches that should be universally available, add configuration in `apps/explorer/config/config.exs`:

```elixir
config :explorer, Explorer.Chain.Cache.YourNewCache, enabled: true
```

#### Runtime-Specific Configuration

For more complex configuration that depends on environment variables or other runtime factors, configure in `config/runtime.exs`:

```elixir
config :explorer, Explorer.Chain.Cache.YourNewCache,
  enabled: ConfigHelper.parse_bool_env_var("YOUR_CACHE_ENABLED", "true"),
  ttl_check_interval: ConfigHelper.parse_time_env_var("YOUR_CACHE_CHECK_INTERVAL", "30s"),
  global_ttl: ConfigHelper.parse_time_env_var("YOUR_CACHE_TTL", "5m")
```

## Usage Examples

### Basic Usage

```elixir
# Getting values
value = Explorer.Chain.Cache.YourNewCache.get(:primary_key)

# Getting all values
all_values = Explorer.Chain.Cache.YourNewCache.get_all()

# Setting values
Explorer.Chain.Cache.YourNewCache.set(:primary_key, "new value")

# Setting the same value for all keys
Explorer.Chain.Cache.YourNewCache.set_all("default value")

# Updating values (goes through handle_update/3)
Explorer.Chain.Cache.YourNewCache.update(:primary_key, "updated value")

# Updating all keys with the same value
Explorer.Chain.Cache.YourNewCache.update_all("mass update value")
```

### Using Generated Named Functions

```elixir
# For a key named :primary_key, these functions are automatically generated:
value = Explorer.Chain.Cache.YourNewCache.get_primary_key()
Explorer.Chain.Cache.YourNewCache.set_primary_key("new value")
Explorer.Chain.Cache.YourNewCache.update_primary_key("updated value")
```

## Advanced Configuration Options

The `use Explorer.Chain.MapCache` macro accepts various options from `ConCache`:

```elixir
use Explorer.Chain.MapCache,
  name: :cache_name,
  keys: [:key1, :key2],
  # ConCache options
  ttl_check_interval: :timer.seconds(1),   # How often to check for expired items
  global_ttl: :timer.minutes(5),           # Default TTL for all items
  touch_on_read: true,                     # Reset TTL countdown when item is accessed
  callback: &custom_callback/1,            # Function to call on cache events
```

### Understanding TTL and Expiry

The expiry mechanism requires two main options:

1. **global_ttl**: The default time-to-live for all entries (in milliseconds)
   - Specifies how long items remain in the cache after last update
   - `:infinity` means entries never expire
   - Can be overridden per-entry when using `set/2`

2. **ttl_check_interval**: How often ConCache runs its cleanup process (in milliseconds)
   - Required for expiry to work
   - Lower values mean more frequent cleanup but higher overhead
   - Set to `false` to disable automatic cleanup; this is the default value if `ttl_check_interval` is not specified

The relationship between these parameters is important to understand:

- **The actual expiration is not immediate** - entries don't automatically disappear the moment they reach their TTL
- Instead, ConCache runs a periodic cleanup task at the interval specified by `ttl_check_interval`
- This cleanup task identifies and removes entries that have exceeded their TTL
- Therefore, an entry might remain in the cache for up to `global_ttl + ttl_check_interval` time

For example, with a `global_ttl` of 5 minutes and a `ttl_check_interval` of 30 seconds:
- An entry should theoretically expire after 5 minutes
- But it might actually remain in the cache for up to 5 minutes and 30 seconds
- After the entry has expired and been removed, the next access will trigger `handle_fallback/1` to fetch fresh data

This approach is more efficient than checking expiration on every access, particularly for caches with high read volumes, as it amortizes the cleanup cost across many operations.

For more granular control, when adding individual items to the cache, you can use `ConCache.Item` structs:

```elixir
# Item with custom TTL
Explorer.Chain.Cache.YourCache.set(:key, %ConCache.Item{
  value: "my value",
  ttl: :timer.seconds(30)  # This item expires after 30 seconds
})

# Item with non-extending TTL
Explorer.Chain.Cache.YourCache.update(:key, %ConCache.Item{
  value: "my value",
  ttl: :no_update  # Updates to this item won't reset its TTL
})

# Item that will never expire
Explorer.Chain.Cache.YourCache.set(:key, %ConCache.Item{
  value: "my value",
  ttl: :infinity  # This item will never expire
})
```

### The Callback Function

The `callback` option specifies a function that ConCache will call on certain cache events:

```elixir
callback: &on_cache_event/1
```

This function receives:
- `{:insert, key, value}` - Called after an item is inserted
- `{:update, key, old_value, new_value}` - Called after an item is updated
- `{:delete, key, value}` - Called before an item is deleted

For example, GasPriceOracle uses a callback to trigger a refresh task when prices expire:

```elixir
defmodule Explorer.Chain.Cache.GasPriceOracle do
  use Explorer.Chain.MapCache,
    # ... other options ...
    callback: &async_task_on_deletion(&1)
    
  # This function is called on cache events
  defp async_task_on_deletion({:delete, _, :gas_prices}) do
    # When gas_prices are deleted, start a new background task to refresh them
    set_old_gas_prices(get_gas_prices())
    safe_get_async_task()
  end
  
  # Ignore other cache events
  defp async_task_on_deletion(_), do: nil
end
```

## Special Case: Async Task Caching

For computationally expensive or time-consuming operations (like complex database queries, API calls, or data transformations), the MapCache can store and manage asynchronous tasks. This pattern is particularly useful when:

1. The data calculation is too slow to perform synchronously during a user request
2. You want to decouple data fetching from the request-response cycle
3. You need to prevent multiple concurrent recalculations of the same data (thundering herd problem)
4. The data needs periodic background updates without blocking user requests

In these cases, you can add an `:async_task` key to your cache to store the PID of a running task:

```elixir
use Explorer.Chain.MapCache,
  name: :cache_name,
  key: :value_key,
  key: :async_task

# The following functions are generated automatically:
def get_async_task, do: get(:async_task)
def set_async_task(value), do: set(:async_task, value)
def update_async_task(value), do: update(:async_task, value)

# Plus a special safe_get_async_task function that checks if the task is still alive
def safe_get_async_task do
  case get_async_task() do
    pid when is_pid(pid) ->
      if Process.alive?(pid) do
        pid
      else
        set_async_task(nil)
        get_async_task()
      end

    not_pid ->
      not_pid
  end
end
```

The flow typically works like this:
1. A user request needs expensive-to-calculate data
2. The code checks if cached data exists; if not, it calls `safe_get_async_task()`
3. If no task is running, `handle_fallback(:async_task)` is called, which starts a new task
4. While the task runs, clients receive a fallback/default value or previous cached data
5. When the task completes, it updates the cache with the new data
6. Future requests receive the cached data until it expires again

### Simple Cache with Async Tasks (GasPriceOracle)

The `GasPriceOracle` cache demonstrates using async tasks for computationally expensive operations. Here's a simplified example focused on the async task pattern:

```elixir
defmodule Explorer.Chain.Cache.GasPriceOracle do
  require Logger

  use Explorer.Chain.MapCache,
    name: :gas_price,
    key: :gas_prices,          # Actual gas price data served to users
    key: :old_gas_prices,      # Previous values (fallback)
    key: :async_task,          # PID of the running calculation task
    global_ttl: :infinity,     # Manual expiration control
    ttl_check_interval: :timer.seconds(1),
    callback: &async_task_on_deletion(&1)

  # Called when the client requests gas prices but entry isn't in cache
  defp handle_fallback(:gas_prices) do
    # Start a task (if not already running) and return old prices immediately
    safe_get_async_task()
    {:return, get_old_gas_prices()}
  end

  # Called by safe_get_async_task() when no task is running
  defp handle_fallback(:async_task) do
    {:ok, task} =
      Task.start_link(fn ->
        try do
          # Perform expensive calculation
          result = calculate_gas_prices()
          
          # Store the result
          set_gas_prices(%ConCache.Item{ttl: global_ttl(), value: result})
        rescue
          e -> Logger.error(["Couldn't update gas prices", Exception.format(:error, e, __STACKTRACE__)])
        end

        # Clean up task reference when done
        set_async_task(nil)
      end)

    # Store the task PID
    {:update, task}
  end

  # Called when ConCache triggers deletion of the gas_prices entry
  defp async_task_on_deletion({:delete, _, :gas_prices}) do
    # Save current prices before they're deleted
    set_old_gas_prices(get_gas_prices())
    
    # Launch background task to refresh data
    safe_get_async_task()
  end

  defp async_task_on_deletion(_), do: nil
end
```

The flow in this pattern works like this:

1. **Initial request**: A client calls `GasPriceOracle.get(:gas_prices)`
   - If the entry exists, it's returned immediately
   - If the entry is missing, `handle_fallback(:gas_prices)` is called

2. **Manual deletion or TTL expiration**: When the `:gas_prices` entry is removed
   - The `async_task_on_deletion` callback is triggered
   - It saves the current value as `:old_gas_prices` before deletion
   - It calls `safe_get_async_task()` to start a refresh task

3. **Refresh task management**: The `safe_get_async_task()` function
   - Checks if a task is already running by looking up `:async_task`
   - If no task is found, `handle_fallback(:async_task)` is called
   - This creates a new background task to calculate fresh values
   - The task updates the cache when it's done

This pattern ensures the cache is always responsive, even when calculations are expensive, by:
- Returning the best available data immediately
- Running expensive operations in the background
- Preventing redundant calculations when multiple requests arrive simultaneously
