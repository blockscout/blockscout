# BufferedTask Implementation Guide

This document provides a comprehensive guide for implementing the `Indexer.BufferedTask` behavior, which provides a framework for efficient batch processing of tasks with memory-aware buffering, automatic retries, and controlled concurrency.

## Overview

The `BufferedTask` module is designed to handle asynchronous processing of large datasets in batches, with features such as:

- **Controlled concurrency**: Limits the number of parallel tasks
- **Automatic retries**: Handles task failures gracefully
- **Prioritized execution**: Supports high-priority tasks
- **Memory-aware buffering**: Controls memory usage and can shrink under memory pressure

BufferedTask is particularly useful for operations that:
1. Process large datasets that would overwhelm the system if handled all at once
2. Require batching for efficiency (like database or RPC operations)
3. Need to be resilient to temporary failures

### Alternative to Complex State Machines

Although not immediately obvious, `BufferedTask` provides an elegant alternative to implementing complex service logic that would traditionally require:
- A single GenServer with multiple state transitions and complex conditional logic
- Multiple coordinated GenServer modules that pass state between them

While traditional state machine implementations often require managing timeouts, retries, and concurrency manually, `BufferedTask` encapsulates these complexities within its core architecture.

### Retriable Tasks Management

`BufferedTask` can effectively manage retriable tasks (tasks that might complete or need to be retried) by:
1. Representing each task with its own data structure, potentially including:
   - Task identifier or type
   - Task state or progress
   - Execution timing information
   - Retry counters or backoff parameters
   
2. Allowing tasks to decide their own fate through the `run/2` callback:
   - Tasks can mark themselves as complete with `:ok`
   - Tasks can update their state and continue with `{:ok, new_state}`
   - Tasks can reschedule themselves with `{:retry, entries}`
   - Tasks can update their state and reschedule with `{:retry, entries, new_state}`

3. Supporting time-based execution through tuple entries:
   - Tasks can be queued as `{timeout, task_data}` where timeout is a Unix timestamp
   - In the `run/2` callback, tasks can check if their timeout has elapsed
   - Tasks that aren't ready can be rescheduled with their original timeout
   - Tasks that are ready can execute and then reschedule with a new timeout

This approach transforms complex state machine logic into a more declarative model where each task manages its own lifecycle, resulting in more maintainable and testable code.

## Basic Implementation

### Understanding the `use Indexer.Fetcher` Macro

When implementing a BufferedTask, you'll typically start by using the `Indexer.Fetcher` macro, which automatically creates a supervision structure for your fetcher:

```elixir
defmodule MyApp.BasicBufferedTask do
  # This macro automatically creates MyApp.BasicBufferedTask.Supervisor and 
  # MyApp.BasicBufferedTask.TaskSupervisor modules for you
  use Indexer.Fetcher, restart: :permanent
  
  # Rest of the implementation...
end
```

The `use Indexer.Fetcher` macro:
1. Creates a supervisor module (`MyApp.BasicBufferedTask.Supervisor`)
2. Creates a task supervisor module (`MyApp.BasicBufferedTask.TaskSupervisor`)
3. Implements a `disabled?/0` function that checks configuration to determine if the fetcher should be disabled
4. Sets up the proper supervision hierarchy

This means you don't need to manually create these supervisor modules - they're automatically generated for you.

### Core Configuration Options

Before diving into the examples, it's important to understand the key configuration options for BufferedTask:

- **flush_interval**: The time in milliseconds between periodic checks for pending tasks. When this interval elapses, BufferedTask will check if there are any tasks to process and, if available concurrency permits, call the `run/2` callback with a batch of tasks. Lower values make the system more responsive to newly added tasks but may cause more overhead. Common values range from 100ms to several seconds. 
  
  *Important*: When `run/2` returns `:retry` (either standalone or as part of a response tuple), BufferedTask will immediately check for available tasks to process without waiting for the flush interval to elapse. Developers need to be aware of this behavior - if you need a deliberate delay before retrying (e.g., to allow temporary RPC or database issues to resolve), you must implement custom delayed retry mechanisms, such as returning tasks with future timestamps or implementing backoff strategies.

- **max_concurrency**: The maximum number of concurrent processing tasks allowed. This controls how many batches can be processed simultaneously. Should be tuned based on the nature of the task - I/O bound operations can use higher values, while CPU-intensive tasks should use lower values.

- **max_batch_size**: The maximum number of entries to include in a single batch for processing. Larger batches improve throughput but increase memory usage and may cause timeouts for long-running operations. Setting this appropriately is crucial for balancing performance and reliability.

- **metadata**: Logger metadata to apply to log messages from the BufferedTask and its spawned tasks. Useful for distinguishing log entries from different fetchers.

These options are typically defined in a `defaults/0` function and can be adjusted through application configuration.

### Minimal Example

With `Indexer.Fetcher` handling the supervision structure, here's a minimal BufferedTask implementation:

```elixir
defmodule MyApp.BasicBufferedTask do
  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @default_max_batch_size 10
  @default_max_concurrency 4
  @flush_interval :timer.seconds(3)

  # Define a child_spec to be used in a supervision tree
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, %{})  # Initial state for your module

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]},
      id: __MODULE__
    )
  end

  # Initialize with an empty queue (no existing data to process)
  @impl BufferedTask
  def init(initial, _reducer, _) do
    initial
  end

  # Process a batch of entries
  @impl BufferedTask
  def run(entries, state) when is_list(entries) do
    # Process your entries here
    entries
    |> Enum.each(fn entry ->
      # Do something with each entry
      IO.puts("Processing: #{inspect(entry)}")
    end)

    # Return :ok if all entries were processed successfully
    :ok
  end

  # Default configuration options
  defp defaults do
    [
      flush_interval: @flush_interval,
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      poll: false,  # Don't automatically poll for new data when queue is empty
      # Use the TaskSupervisor that was automatically created by the Indexer.Fetcher macro
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :my_buffered_task]
    ]
  end
end
```

### Example with Initial Data Loading and Polling

For cases where you need to populate the queue with initial data and continue polling for new data when the queue is empty, use the `poll: true` option and modify the `init/3` function:

```elixir
def child_spec([init_options, gen_server_options]) do
  merged_init_opts =
    defaults()
    |> Keyword.merge(init_options)
    |> Keyword.put(:state, %{})  # Initial state for your module

  Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]},
    id: __MODULE__
  )
end

defp defaults do
  [
    flush_interval: @flush_interval,
    max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
    max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
    poll: true,  # When true, BufferedTask will call init/3 again after all items are processed
    task_supervisor: __MODULE__.TaskSupervisor,
    metadata: [fetcher: :my_buffered_task]
  ]
end

@impl BufferedTask
def init(initial, reducer, _) do
  # Load initial data from a database
  {:ok, final} =
    Explorer.Repo.stream_reduce(
      from(item in MyApp.Item, where: item.status == :pending),
      initial,
      reducer
    )
    
  final
end
```

The `poll: true` option is important here as it causes BufferedTask to:
1. Call your `init/3` function again after all items in the queue have been processed
2. Continually check for new data without manually re-scheduling tasks
3. Create a continuous processing loop that handles both initial and new data

This is particularly useful for handling ongoing streams of data, like continuously processing new pending items in a database. If you only want to process the initial batch of data once without polling for new data, use `poll: false` instead.

### Example with Custom State

When your task needs to maintain state between executions:

```elixir
def child_spec([init_options, gen_server_options]) do
  merged_init_opts =
    defaults()
    |> Keyword.merge(init_options)
    |> Keyword.put(:state, %{
      processed_count: 0,
      last_processed_at: nil
    })

  Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]},
    id: __MODULE__
  )
end

@impl BufferedTask
def run(entries, state) when is_list(entries) do
  # Process entries...
  
  # Update state with new information
  new_state = %{
    state |
    processed_count: state.processed_count + length(entries),
    last_processed_at: DateTime.utc_now()
  }
  
  {:ok, new_state}
end
```

## Adding Data to the Queue

You can add data to the BufferedTask queue programmatically:

```elixir
defmodule MyApp.BufferedTaskWithAPI do
  # ... same as above ...
  
  # Public API to add items to the queue
  def async_handle_items(items) do
    BufferedTask.buffer(__MODULE__, items, false)
  end
end
```

## Configuration

### Adding to Supervision Tree and Configuration Control

The `Indexer.Fetcher` macro provides a built-in mechanism for enabling or disabling your fetcher without removing it from the supervision tree. The recommended approach is to always add your supervisor to the supervision tree and control its activation through configuration.

In `apps/indexer/lib/indexer/supervisor.ex`, simply add your task's supervisor module unconditionally:

```elixir
# In the main Indexer.Supervisor module:
basic_fetchers = [
  # ... existing fetchers ...
  {MyApp.BasicBufferedTask.Supervisor, [
    [json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]
  ]},
  # ... other fetchers ...
]
```

Then, in `config/runtime.exs`, control whether the fetcher is enabled or disabled:

```elixir
config :indexer, MyApp.BasicBufferedTask.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("MY_BUFFERED_TASK_DISABLED", "false")
```

This approach is preferable because:

1. The `start_link/2` function generated by the `Indexer.Fetcher` macro already checks the `disabled?` flag and returns `:ignore` if disabled, which is properly handled by the supervision tree
2. Other modules can use `MyApp.BasicBufferedTask.Supervisor.disabled?/0` to check if the fetcher is disabled before attempting to use it

#### Alternative Configuration with `configure` Helper

If for some reason you cannot use the `disabled?` flag on the supervisor, you can use the `configure/2` helper in the `Indexer.Supervisor` module combined with an `enabled` flag:

```elixir
# In the main Indexer.Supervisor module:
basic_fetchers = [
  # ... existing fetchers ...
  configure(MyApp.BasicBufferedTask.Supervisor, [
    [json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]
  ]),
  # ... other fetchers ...
]
```

This approach conditionally adds the supervisor to the supervision tree based on the `enabled` configuration value, but should only be used when the built-in `disabled?` mechanism cannot be used for some reason.

### Runtime Configuration

In `config/runtime.exs`, you have two main approaches to configure your BufferedTask:

```elixir
# Primary approach: Configure using the disabled? flag on the supervisor
config :indexer, MyApp.BasicBufferedTask.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("MY_BUFFERED_TASK_DISABLED", "false")

# Module-specific configuration for performance tuning
config :indexer, MyApp.BasicBufferedTask,
  concurrency: ConfigHelper.parse_integer_env_var("MY_BUFFERED_TASK_CONCURRENCY", 10),
  batch_size: ConfigHelper.parse_integer_env_var("MY_BUFFERED_TASK_BATCH_SIZE", 50),
  interval: ConfigHelper.parse_time_env_var("MY_BUFFERED_TASK_INTERVAL", "30s")

# Alternative approach: Using enabled flag (only when configure helper is used in supervisor.ex)
config :indexer, MyApp.BasicBufferedTask.Supervisor,
  enabled: ConfigHelper.parse_bool_env_var("MY_BUFFERED_TASK_ENABLED", "true")
```

The primary approach uses the `disabled?` flag which is checked by the supervisor's `start_link/2` function. The alternative approach uses an `enabled` flag that works with the `configure/2` helper in the supervisor module.

Note that you should choose one approach consistently - either:
1. Add the supervisor directly to `basic_fetchers` and use the `disabled?` flag (recommended)
2. Use the `configure/2` helper with the supervisor and the `enabled` flag

Mixing both approaches can lead to confusing behavior.

### API Methods Using the disabled? Flag

In your module, you can leverage the automatically generated `disabled?/0` function when creating API methods:

```elixir
def async_handle_items(items) do
  if __MODULE__.Supervisor.disabled?() do
    :ok
  else
    BufferedTask.buffer(__MODULE__, items, false)
  end
end
```

This ensures that your task won't attempt to schedule work when it's been disabled through configuration.

## Advanced Usage and Common Patterns

### Pattern Matching on Different Entry Formats

A single BufferedTask module can efficiently handle multiple entry formats by using pattern matching:

```elixir
defmodule MyApp.MultiFormatProcessor do
  use Indexer.Fetcher, restart: :permanent
  
  @impl BufferedTask
  def run(entries, state) do
    # Process each entry based on its format
    results = Enum.map(entries, &process_entity(&1, state))

   # ...process results...
  end
  
  # Handle regular entry format
  defp process_entity({id, data}, state) do
    # Process regular entry...
  end
  
  # Handle timed entry format
  defp process_entity({timestamp, id, data}, state) do
    # Process timed entry...
  end
end
```

### Time-based Task Scheduling

For tasks that should run at specific times or with delays:

```elixir
@impl BufferedTask
def run([{timeout, task_data}], _state) do
  now = DateTime.to_unix(DateTime.utc_now(), :millisecond)
  
  if timeout <= now do
    # Process the task
    process_task(task_data)
    
    # Schedule the next execution with a new timeout
    # Directly buffer the next execution rather than returning {:retry, ...}
    # This adds the task to the queue, but it won't be picked up immediately
    # due to the flush_interval delay before queue processing
    next_timeout = now + :timer.minutes(5)
    BufferedTask.buffer(__MODULE__, [{next_timeout, task_data}], false)
    
    # Return :ok to indicate this batch is complete
    :ok
  else
    # Not time yet, return to the queue with the same timeout
    {:retry, [{timeout, task_data}]}
  end
end

defp process_task(data) do
  # Task implementation based on the data
end

# Schedule a task to run after a delay
def async_handle(data, delay_ms) do
  timeout = DateTime.to_unix(DateTime.utc_now(), :millisecond) + delay_ms
  # Using high priority (true) will ensure the task is processed as soon as possible
  # particularly important when delay_ms is 0 for immediate execution
  BufferedTask.buffer(__MODULE__, [{timeout, data}], true)
end
```

### Handling Partial Success with Retries

When some entries in a batch succeed while others fail:

```elixir
@impl BufferedTask
def run(entries, _state) do
  # Process entries and track failures
  {successful, failed} =
    Enum.reduce(entries, {[], []}, fn entry, {successful, failed} ->
      case process_entry(entry) do
        :ok -> {[entry | successful], failed}
        :error -> {successful, [entry | failed]}
      end
    end)
    
  if failed == [] do
    # All entries succeeded
    :ok
  else
    # Retry failed entries
    {:retry, failed}
  end
end
```

### Task Dependencies and Status Tracking

For complex tasks with dependencies and progress tracking:

```elixir
def child_spec([init_options, gen_server_options]) do
  merged_init_opts =
    defaults()
    |> Keyword.merge(init_options)
    |> Keyword.put(:state, %{
      completed_tasks: %{},
      task_data: %{
        task_one: %{param1: "value1", param2: "value2"},
        task_two: %{param1: "value3", param2: "value4"}
      },
      intervals: %{
        task_one: :timer.seconds(30),
        task_two: :timer.minutes(5)
      },
      dependencies: %{
        task_one: [],            # task_one has no dependencies
        task_two: [:task_one]    # task_two depends on task_one
      }
    })

  Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
end

@impl BufferedTask
def run([{timeout, task_type}], state) do
  now = DateTime.to_unix(DateTime.utc_now(), :millisecond)
  
  if timeout <= now do
    # Process the task
    {status, updated_state} = process_task(task_type, state)
    
    case status do
      :complete ->
        # Update completed state
        completed = Map.put(updated_state.completed_tasks, task_type, true)
        final_state = %{updated_state | completed_tasks: completed}
        
        # Schedule dependent tasks if needed
        maybe_schedule_dependent_tasks(task_type, final_state)
        
        {:ok, final_state}
        
      :retry ->
        # Reschedule with appropriate interval
        next_time = now + updated_state.intervals[task_type]
        {:retry, [{next_time, task_type}], updated_state}
    end
  else
    # Not time yet, return to the queue with the same timeout
    {:retry, [{timeout, task_type}]}
  end
end

defp maybe_schedule_dependent_tasks(completed_task_type, state) do
  # Find all tasks that directly depend on the completed task
  dependent_tasks =
    Enum.filter(state.dependencies, fn {task, dependencies} -> 
      completed_task_type in dependencies
    end)
    |> Enum.map(fn {task, _} -> task end)
  
  # For each dependent task, check if all its dependencies are now completed
  Enum.each(dependent_tasks, fn task ->
    dependencies = state.dependencies[task]
    
    # Check if all dependencies for this task are completed
    all_dependencies_met? =
      Enum.all?(dependencies, fn dependency -> 
        Map.get(state.completed_tasks, dependency, false)
      end)
    
    # If all dependencies are completed, schedule this task
    if all_dependencies_met? and not Map.get(state.completed_tasks, task, false) do
      # Schedule the task with immediate execution (timeout = 0)
      BufferedTask.buffer(__MODULE__, [{0, task}], true)
    end
  end)
  
  :ok
end
```

### Two-Phase Initialization

For services requiring complex initialization or runtime configuration:

**Why use two-phase initialization?**
- **Supervisor resilience**: Moving initialization to a separate task prevents supervisor failures if initialization fails
- **Async operations**: Allows performing async API calls, DB queries, and RPC requests safely
- **Error handling**: Initialization failures can be retried without affecting other services
- **Dynamic startup**: Tasks can be scheduled based on runtime conditions and dependencies

```elixir
@impl BufferedTask
def init(initial, reducer, _) do
  # Schedule just the initialization task immediately
  reducer.(:init_worker, initial)
end

@impl BufferedTask
def run([:init_worker], state) do
  # Perform complex initialization tasks that might involve:
  # - API calls to fetch necessary configuration
  # - Database queries to determine starting points
  # - Setting up connections to external systems
  initialized_state = initialize_workers(state)
  
  # Note: In a real implementation, you would typically call BufferedTask.buffer here 
  # to schedule initial work tasks, or have another system component add tasks to this queue

  {:ok, initialized_state}
end

def run(entities, state) do
  # Regular tasks processing by using initialized state
  # Check if contract addresses are available before processing
  case Map.get(state.config, :contract_addresses) do
    nil ->
      Logger.debug("Contract addresses not yet initialized, retrying...")
      :retry
      
    _addresses ->
      # Process entities normally since contract addresses are available
      process_entities(entities, state)
  end
end

defp process_entities(entities, state) do
  # Regular entity processing logic here
  {:ok, state}
end

defp initialize_workers(state) do
  # Complex initialization logic here
  # For example, fetch runtime configurations:
  config_from_db = fetch_database_config()
  contract_addresses = fetch_contract_addresses_from_api()
  
  # Update state with runtime values
  %{state | 
    config: Map.merge(state.config, %{
      contract_addresses: contract_addresses,
      runtime_settings: config_from_db
    })
  }
end
```

### Waiting Pattern with Conditional Startup

For services that need to wait for certain conditions before starting their main work (e.g., waiting for blocks to be indexed):

```elixir
  @impl BufferedTask
  def init(initial, reducer, _) do
    # Schedule a waiting task that checks for conditions
    time_of_start = DateTime.utc_now()
    reducer.({:wait_for_condition, time_of_start}, initial)
  end

  @impl BufferedTask
  def run([{:wait_for_condition, time_of_start}], _) do
    # Check if our condition is met (e.g., a specific block has been indexed)
    case DbUtils.check_for_required_condition(time_of_start) do
      {:ok, starting_point} ->
        Logger.info("Required condition met, starting main tasks")
        
        # Schedule the main work now that conditions are met
        BufferedTask.buffer(__MODULE__, [{:main_work, starting_point}], false)
        :ok

      {:error, _} ->
        Logger.debug("Still waiting for required condition to be met")
        # Re-schedule the waiting task
        :retry
    end
  end
  
  # Once the condition is met, this handles the main work
  def run([{:main_work, starting_point}], state) do
    # Main work processing logic...
  end
end
```

### Limiting Initial Load

Control the initial queue size when loading data:

```elixir
@max_queue_size 5000

@impl BufferedTask
def init(initial_acc, reducer, _) do
  {:ok, acc} =
    MyApp.stream_pending_items(
      initial_acc,
      fn data, acc ->
        reduce_if_queue_is_not_full(data, acc, reducer)
      end
    )
    
  acc
end

defp reduce_if_queue_is_not_full(data, acc, reducer) do
  bound_queue = GenServer.call(__MODULE__, :state).bound_queue
  
  if bound_queue.size >= @max_queue_size do
    :timer.sleep(500)
    reduce_if_queue_is_not_full(data, acc, reducer)
  else
    reducer.(data, acc)
  end
end
```

### Transformer Reducers

Modify the data format during initial loading:

```elixir
@impl BufferedTask
def init(initial, reducer, _) do
  {:ok, final} =
    Explorer.Repo.stream_reduce(
      query,
      initial,
      fn record, acc ->
        # Transform the record before passing to reducer
        transformed_data = %{
          id: record.id,
          type: identify_type(record),
          priority: calculate_priority(record)
        }
        
        reducer.(transformed_data, acc)
      end
    )
    
  final
end
```

### Self-Stopping Tasks

For tasks that need to terminate themselves upon completion:

```elixir
defmodule SelfStoppingTask do
  use Indexer.Fetcher, restart: :transient  # This is crucial for allowing the process to terminate
  
  # ...other module code...

  def child_spec([init_options, gen_server_options]) do
    # Merge options
    merged_init_opts = 
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, initial_state)

    # Note the restart: :transient option which allows the process to stop
    # when GenServer.stop is called without being restarted by the supervisor
    Supervisor.child_spec(
      {BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]},
      id: __MODULE__,
      restart: :transient  # Allow process to terminate without restart
    )
  end

  @impl BufferedTask
  def run(entries, state) do
    case process_entries(entries) do
      {:ok, :complete} ->
        # Finished all work, stop the process
        # :shutdown reason is recommended for supervised processes
        # as it signals a controlled shutdown to the supervisor
        GenServer.stop(__MODULE__, :shutdown)
        :ok
        
      {:ok, :continue} ->
        # More work to do
        :ok
    end
  end
end
```

### Custom Event Handling with "Dead Hand" Timers

BufferedTask modules can implement custom `handle_info/2` callbacks to process events outside the standard flow, enabling a "Dead Hand" timer pattern that ensures final operations like statistics reporting occur even after the queue becomes inactive:

```elixir
@log_interval :timer.minutes(1)

@impl BufferedTask
def run(entries, state) do
  # Process entries
  new_count = state.processed_count + length(entries)
  
  # Update state with new count
  updated_state = %{state | processed_count: new_count}
  
  # Reset timer and schedule statistics logging
  updated_state_with_timer = maybe_schedule_statistics_logging(updated_state)
  
  {:ok, updated_state_with_timer}
end

# Handle the statistics logging timer event
def handle_info(:log_statistics, state) do
  # Log final statistics and reset timer state
  Logger.info("Final statistics report: processed #{state.processed_count} items")
  
  # Clear timer references to allow garbage collection
  {:noreply, %{state | statistics_timer: nil, last_log_time: nil}}
end

# The "Dead Hand" timer pattern ensures final operations occur even after activity stops
defp maybe_schedule_statistics_logging(state) do
  # Cancel existing timer if present to avoid duplicate events
  if state.statistics_timer do
    Process.cancel_timer(state.statistics_timer)
  end

  # Schedule new timer to ensure statistics are logged even if no new items arrive
  timer_ref = Process.send_after(self(), :log_statistics, @log_interval)
  
  now = DateTime.utc_now()
  
  # Initialize last_log_time on first activity
  state_with_log_time =
    if is_nil(state.last_log_time), do: %{state | last_log_time: now}, else: state

  # Log periodically during active periods based on threshold
  if not is_nil(state_with_log_time.last_log_time) and
        DateTime.diff(now, state_with_log_time.last_log_time, :second) >= @log_interval / 1000 do
    Logger.info("Periodic statistics: processed #{state.processed_count} items")
    %{state_with_log_time | last_log_time: now, statistics_timer: timer_ref}
  else
    %{state_with_log_time | statistics_timer: timer_ref}
  end
end
```

## Best Practices

1. **Batch Size and Concurrency**: Choose appropriate values based on the nature of your tasks. I/O-bound tasks may benefit from higher concurrency, while CPU-bound tasks might need lower concurrency but larger batch sizes.

2. **Error Handling**: Always handle errors gracefully within the `run/2` function. Use the `:retry` return value for recoverable errors.

3. **State Management**: Keep state minimal and use it only for necessary information that must persist between task runs.

4. **Memory Awareness**: Be cognizant of memory usage, especially when loading initial data. Use streaming where possible.

5. **Prioritization**: Use front buffering for urgent tasks that should be processed before regular tasks.

6. **Idempotence**: Design tasks so that repeated executions have the same outcome as a single execution. For example, if a task updates a transaction status from "pending" to "completed", running it multiple times should not cause errors or change the already "completed" status. This is especially important since BufferedTask's `run/2` callback includes retry mechanisms.

7. **Backpressure**: Implement mechanisms to slow down task creation when the system is under load.
