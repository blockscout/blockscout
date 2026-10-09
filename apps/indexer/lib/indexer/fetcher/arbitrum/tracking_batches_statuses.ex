# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Arbitrum.TrackingBatchesStatuses do
  @moduledoc """
    Manages the tracking and updating of the statuses of rollup batches,
    confirmations, and cross-chain message executions for an Arbitrum rollup.

    This module orchestrates the workflow for discovering new and historical
    batches of rollup transactions, confirmations of rollup blocks, and executions
    of L2-to-L1 messages. It ensures the accurate tracking and updating of the
    rollup process stages.

    The fetcher uses a BufferedTask-based approach for task scheduling, where each
    type of task is scheduled independently with appropriate intervals. This provides
    better error isolation and task management.

    Task types include:
    - `:new_batches`: Discovers new batches of rollup transactions and
      updates their statuses.
    - `:new_confirmations`: Identifies new confirmations of rollup blocks to
      update their statuses.
    - `:new_executions`: Finds new executions of L2-to-L1 messages to update
      their statuses.
    - `:historical_batches`: Processes historical batches of rollup
      transactions.
    - `:missing_batches`: Inspects for missing batches of rollup transactions.
    - `:historical_confirmations`: Handles historical confirmations of
      rollup blocks, below the start point of the new confirmations discovery.
    - `:historical_executions`: Manages historical executions of L2-to-L1
      messages.
    - `:settlement_transactions_finalization`: Finalizes the status of lifecycle
      transactions, confirming the blocks and messages involved.

    Task scheduling behavior:
    Each task is responsible for its own re-scheduling. Some tasks (historical ones)
    can be conditionally re-scheduled based on their completion status. The interval
    between task executions depends on:
    - Type of the task (new vs historical)
    - Failure frequency of the task

    Tasks that fail abnormally within a configurable threshold period will enter a
    cooldown state for 10 minutes to prevent resource exhaustion.

    Initialization architecture:
    The module uses a two-phase initialization process:
    1. Static configuration in `child_spec`:
       - Extracts configuration from application environment
       - Sets up initial intervals for tasks
       - Configures RPC settings and basic parameters
       This phase handles only configuration that is locally available and does
       not depend on external data sources, ensuring supervisor startup can
       proceed reliably.

    2. Dynamic configuration in `initialize_workers`:
       - Retrieves contract addresses through RPC calls
       - Determines block numbers from database state
       - Sets up task-specific data based on current chain state
       This phase is executed as the first scheduled task, allowing for proper
       error handling and retries if external data sources (RPC node, database)
       are temporarily unavailable. This separation ensures system resilience
       by keeping supervisor startup independent of external dependencies.

    Discovery of rollup transaction batches is executed by requesting logs on L1
    that correspond to the `SequencerBatchDelivered` event emitted by the Arbitrum
    `SequencerInbox` contract.

    Discovery of rollup block confirmations is executed by requesting logs on L1
    that correspond to the `SendRootUpdated` event emitted by the Arbitrum `Outbox`
    contract. Each event gives one row of the table of confirmations, and the
    processes keep their cursors in the database. See
    `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Tasks`.

    Discovery of the L2-to-L1 message executions occurs by requesting logs on L1
    that correspond to the `OutBoxTransactionExecuted` event emitted by the
    Arbitrum `Outbox` contract.

    When processing batches or confirmations, the L2-to-L1 messages included in
    the corresponding rollup blocks are updated to reflect their status changes.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1, log_warning: 1]

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Arbitrum.Workers.Batches.Tasks, as: BatchesDiscoveryTasks
  alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Tasks, as: ConfirmationsDiscoveryTasks
  alias Indexer.Fetcher.Arbitrum.Workers.{L1Finalization, NewL1Executions}

  alias EthereumJSONRPC.Arbitrum, as: ArbitrumRpc
  alias EthereumJSONRPC.Utility.RangesHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Helper, as: IndexerHelper

  require Logger

  @behaviour BufferedTask

  # 250ms interval between processing buffered entries.
  # Note: This interval has no effect on retry behavior - when a task fails or
  # is explicitly retried via :retry return value, it is re-queued and the next
  # available task is picked up immediately without this delay.
  @idle_interval 250
  # Only one task at a time
  @max_concurrency 1
  # Process one task per batch
  @max_batch_size 1

  # 10 minutes cooldown interval for failed tasks
  @cooldown_interval :timer.minutes(10)

  # Catchup tasks (historical batches, confirmations, etc.) need to run as quickly as possible
  # since they are only needed when indexing a rollup chain that already has many blocks.
  # This interval is hardcoded since these tasks should complete rapidly and don't need
  # to be configurable.
  @catchup_recheck_interval :timer.seconds(2)

  @stoppable_tasks [:historical_batches, :missing_batches, :historical_confirmations, :historical_executions]

  @typep fetcher_task ::
           :new_batches
           | :new_confirmations
           | :new_executions
           | :historical_batches
           | :missing_batches
           | :historical_confirmations
           | :historical_executions
           | :settlement_transactions_finalization
  @typep queued_task :: :init_worker | {non_neg_integer(), fetcher_task()}

  @typep stoppable_fetcher_task ::
           :historical_batches | :missing_batches | :historical_confirmations | :historical_executions
  @typep completion_status :: %{stoppable_fetcher_task() => boolean()}
  @typep fetcher_tasks_intervals :: %{fetcher_task() => non_neg_integer()}
  @typep fetcher_tasks_data :: %{fetcher_task() => map()}

  # Creates a child specification for the BufferedTask supervisor. Extracts and merges
  # configuration from application environment, sets up task intervals (standard for new
  # tasks, catchup for historical ones), initializes RPC configurations for parent and
  # rollup chains, and creates the initial state with task scheduling parameters.
  # Returns a transient supervisor child spec with the configured BufferedTask.
  def child_spec([init_options, gen_server_options]) do
    {json_rpc_named_arguments, init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    # Extract configuration from application environment
    config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
    l1_rpc = config_common[:l1_rpc]
    l1_rpc_block_range = config_common[:l1_rpc_block_range]
    l1_rollup_address = config_common[:l1_rollup_address]
    l1_rollup_init_block = config_common[:l1_rollup_init_block]
    l1_start_block = config_common[:l1_start_block]
    l1_rpc_chunk_size = config_common[:l1_rpc_chunk_size]
    rollup_chunk_size = config_common[:rollup_chunk_size]

    config_tracker = Application.get_all_env(:indexer)[__MODULE__]
    recheck_interval = config_tracker[:recheck_interval]
    messages_to_blocks_shift = config_tracker[:messages_to_blocks_shift]
    track_l1_transaction_finalization = config_tracker[:track_l1_transaction_finalization]
    finalized_confirmations = config_tracker[:finalized_confirmations]
    confirmation_batches_depth = config_tracker[:confirmation_batches_depth]
    new_batches_limit = config_tracker[:new_batches_limit]
    missing_batches_range = config_tracker[:missing_batches_range]
    node_interface_address = config_tracker[:node_interface_contract]

    failure_interval_threshold =
      config_tracker[:failure_interval_threshold] || min(20 * recheck_interval, :timer.minutes(10))

    # Configure intervals for each task type
    intervals = %{
      new_batches: recheck_interval,
      new_confirmations: recheck_interval,
      new_executions: recheck_interval,
      historical_batches: @catchup_recheck_interval,
      missing_batches: @catchup_recheck_interval,
      historical_confirmations: @catchup_recheck_interval,
      historical_executions: @catchup_recheck_interval,
      settlement_transactions_finalization: recheck_interval
    }

    indexer_first_block =
      RangesHelper.get_min_block_number_from_range_string(Application.get_env(:indexer, :block_ranges))

    # Set up initial configuration structure
    initial_config = %{
      l1_rpc: %{
        json_rpc_named_arguments: IndexerHelper.l1_json_rpc_named_arguments(l1_rpc),
        logs_block_range: l1_rpc_block_range,
        chunk_size: l1_rpc_chunk_size,
        track_finalization: track_l1_transaction_finalization,
        finalized_confirmations: finalized_confirmations
      },
      rollup_rpc: %{
        json_rpc_named_arguments: json_rpc_named_arguments,
        chunk_size: rollup_chunk_size
      },
      recheck_interval: recheck_interval,
      l1_rollup_address: l1_rollup_address,
      l1_start_block: l1_start_block,
      l1_rollup_init_block: l1_rollup_init_block,
      new_batches_limit: new_batches_limit,
      missing_batches_range: missing_batches_range,
      messages_to_blocks_shift: messages_to_blocks_shift,
      confirmation_batches_depth: confirmation_batches_depth,
      node_interface_address: node_interface_address,
      rollup_first_block: indexer_first_block,
      failure_interval_threshold: failure_interval_threshold
    }

    # Initial state structure
    initial_state = %{
      config: initial_config,
      intervals: intervals,
      task_data: %{},
      completed_tasks: %{}
    }

    buffered_task_init_options =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, initial_state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, buffered_task_init_options}, gen_server_options]},
      id: __MODULE__,
      restart: :transient
    )
  end

  defp defaults do
    [
      flush_interval: @idle_interval,
      max_concurrency: @max_concurrency,
      max_batch_size: @max_batch_size,
      poll: false,
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :arbitrum_batches_tracker]
    ]
  end

  @impl BufferedTask
  def init(initial, reducer, _state) do
    # Schedule the initialization task immediately
    reducer.(:init_worker, initial)
  end

  @impl BufferedTask
  @spec run([queued_task()], map()) :: {:ok, map()} | {:retry, [queued_task()], map()} | :retry
  def run(tasks, state)

  # Initializes the worker state and schedules all tasks for execution. Configures the
  # initial state with RPC/DB values, sets up tasks in order (new batches/confirmations/
  # executions followed by historical ones), defines their completion states, and
  # conditionally disables missing batches discovery and settlement transactions
  # finalization based on configuration.
  def run([:init_worker], state) do
    # Complete configuration with RPC/DB dependent values
    configured_state = initialize_workers(state)

    # Get current timestamp for initial task scheduling
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    # Define all possible tasks with their initial timestamps in desired order
    default_tasks_to_run = [
      {now, :new_batches},
      {now, :new_confirmations},
      {now, :new_executions},
      {now, :historical_batches},
      {now, :historical_confirmations},
      {now, :historical_executions},
      {now, :missing_batches},
      {now, :settlement_transactions_finalization}
    ]

    # Define default completion state for all tasks
    default_completion_state = %{
      historical_batches: false,
      missing_batches: false,
      historical_confirmations: false,
      historical_executions: false
    }

    # Process tasks and completion state based on configuration checks
    {tasks_to_run, completion_state} =
      {default_tasks_to_run, default_completion_state}
      |> maybe_disable_missing_batches_discovery(configured_state)
      |> maybe_disable_settlement_transactions_finalization(configured_state)

    BufferedTask.buffer(__MODULE__, tasks_to_run, false)

    updated_state = Map.put(configured_state, :completed_tasks, completion_state)
    {:ok, updated_state}
  end

  # Executes or returns a task back to the queue based on its timeout and failure threshold.
  #
  # The function evaluates three conditions in sequence:
  # 1. Whether the task's timeout has elapsed (current time >= timeout)
  # 2. Whether the task hasn't exceeded the failure threshold or is an initial task (timeout == 0)
  #
  # If all conditions are met, executes the appropriate task runner. Otherwise:
  # - If timeout hasn't elapsed: Returns the task to the queue with the same timeout
  # - If failure threshold exceeded: Applies a 10-minute cooldown and reschedules
  #
  # ## Parameters
  # - `timeout`: Unix timestamp in milliseconds when the task should execute
  # - `task_tag`: Atom identifying the type of task to run
  # - `state`: Current state containing configuration and intervals
  #
  # ## Returns
  # - `{:ok, state}` on successful execution
  # - `{:retry, [{timeout, task_tag}], state}` when task needs to be rescheduled
  def run([{timeout, task_tag}], state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    with {:timeout_elapsed, true} <- {:timeout_elapsed, timeout <= now},
         {:threshold_ok, true} <- {:threshold_ok, now - timeout <= state.config.failure_interval_threshold},
         {:runner_defined, runner} when not is_nil(runner) <- {:runner_defined, Map.get(task_runners(), task_tag)} do
      runner.(state)
    else
      {:timeout_elapsed, false} ->
        # Task is scheduled for future execution, retry with same timeout
        {:retry, [{timeout, task_tag}], state}

      {:threshold_ok, false} ->
        # Task has been failing too frequently, apply cooldown
        new_timeout = now + @cooldown_interval

        log_warning(
          "Task #{task_tag} has been failing abnormally, applying cooldown for #{div(@cooldown_interval, 1000)} seconds"
        )

        {:retry, [{new_timeout, task_tag}], state}

      {:runner_defined, nil} ->
        # Unknown task type
        log_warning("Unknown task type: #{inspect(task_tag)}")
        {:ok, state}
    end
  end

  defp task_runners do
    %{
      new_batches: &handle_new_batches/1,
      new_confirmations: &handle_new_confirmations/1,
      new_executions: &handle_new_executions/1,
      historical_batches: &handle_historical_batches/1,
      missing_batches: &handle_missing_batches/1,
      historical_confirmations: &handle_historical_confirmations/1,
      historical_executions: &handle_historical_executions/1,
      settlement_transactions_finalization: &handle_settlement_transactions_finalization/1
    }
  end

  # Initializes the worker state with contract addresses and block information
  @spec initialize_workers(%{
          :config => map(),
          optional(any()) => any()
        }) :: %{:config => map(), :task_data => fetcher_tasks_data(), optional(any()) => any()}
  defp initialize_workers(state) do
    json_l1_rpc_named_arguments = state.config.l1_rpc.json_rpc_named_arguments
    l1_rollup_address = state.config.l1_rollup_address

    %{outbox: outbox_address, sequencer_inbox: sequencer_inbox_address} =
      ArbitrumRpc.get_contracts_for_rollup(
        l1_rollup_address,
        :inbox_outbox,
        json_l1_rpc_named_arguments
      )

    l1_start_block = Rpc.get_l1_start_block(state.config.l1_start_block, json_l1_rpc_named_arguments)

    new_batches_start_block = DbSettlement.l1_block_to_discover_latest_committed_batch(l1_start_block)
    historical_batches_end_block = DbSettlement.l1_block_to_discover_earliest_committed_batch(l1_start_block - 1)

    new_executions_start_block = DbMessages.l1_block_to_discover_latest_execution(l1_start_block)
    historical_executions_end_block = DbMessages.l1_block_to_discover_earliest_execution(l1_start_block - 1)

    {lowest_batch, missing_batches_end_batch} = DbSettlement.get_min_max_batch_numbers()

    updated_config =
      Map.merge(state.config, %{
        l1_start_block: l1_start_block,
        l1_outbox_address: outbox_address,
        l1_sequencer_inbox_address: sequencer_inbox_address,
        lowest_batch: lowest_batch
      })

    task_data = %{
      new_batches: %{
        start_block: new_batches_start_block
      },
      historical_batches: %{
        end_block: historical_batches_end_block
        # lowest_l1_block_for_commitments: nil <- will be added during handle_historical_batches
      },
      # The cursors of the confirmations discovery live in the database. The tasks
      # read them at their first run, or compute the start point if no cursor exists.
      new_confirmations: %{
        cursor: nil
      },
      historical_confirmations: %{
        cursor: nil
      },
      new_executions: %{
        start_block: new_executions_start_block
      },
      historical_executions: %{
        end_block: historical_executions_end_block
      },
      missing_batches: %{
        end_batch: missing_batches_end_batch
      }
    }

    %{state | config: updated_config, task_data: task_data}
  end

  # Conditionally disables missing batches discovery based on configuration
  @spec maybe_disable_missing_batches_discovery({[queued_task()], completion_status()}, %{
          optional(any()) => any()
        }) :: {[queued_task()], completion_status()}
  defp maybe_disable_missing_batches_discovery({tasks, completion}, state) do
    if BatchesDiscoveryTasks.run_missing_batches_discovery?(state) do
      {tasks, completion}
    else
      log_info("Missing batches inspection is disabled")
      {delete_task_by_tag(tasks, :missing_batches), %{completion | missing_batches: true}}
    end
  end

  # Conditionally disables settlement transactions finalization based on configuration
  @spec maybe_disable_settlement_transactions_finalization({[queued_task()], completion_status()}, %{
          optional(any()) => any()
        }) :: {[queued_task()], completion_status()}
  defp maybe_disable_settlement_transactions_finalization({tasks, completion}, state) do
    if L1Finalization.run_settlement_transactions_finalization?(state) do
      {tasks, completion}
    else
      log_info("Settlement transactions finalization is disabled")
      {delete_task_by_tag(tasks, :settlement_transactions_finalization), completion}
    end
  end

  # Deletes a task from the tasks list by its tag, ignoring the timeout value
  @spec delete_task_by_tag([queued_task()], fetcher_task()) :: [queued_task()]
  defp delete_task_by_tag(tasks, tag) do
    Enum.reject(tasks, fn {_timeout, task_tag} -> task_tag == tag end)
  end

  # Handles the discovery of new batches of rollup transactions
  defp handle_new_batches(state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok, updated_state} = BatchesDiscoveryTasks.check_new(state)

    next_run_time = now + updated_state.intervals[:new_batches]
    BufferedTask.buffer(__MODULE__, [{next_run_time, :new_batches}], false)

    {:ok, updated_state}
  end

  # Handles the discovery of new confirmations for rollup blocks
  defp handle_new_confirmations(state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok, updated_state} = ConfirmationsDiscoveryTasks.check_new(state)

    next_run_time = now + updated_state.intervals[:new_confirmations]
    BufferedTask.buffer(__MODULE__, [{next_run_time, :new_confirmations}], false)

    {:ok, updated_state}
  end

  # Handles the discovery of new L2-to-L1 message executions
  defp handle_new_executions(state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok, updated_state} = NewL1Executions.discover_new_l1_messages_executions(state)

    next_run_time = now + updated_state.intervals[:new_executions]
    BufferedTask.buffer(__MODULE__, [{next_run_time, :new_executions}], false)

    {:ok, updated_state}
  end

  # Handles the discovery of historical batches of rollup transactions
  defp handle_historical_batches(state) do
    run_worker_with_conditional_rescheduling(
      state,
      :historical_batches,
      &BatchesDiscoveryTasks.check_historical/1,
      &BatchesDiscoveryTasks.historical_batches_discovery_completed?/1
    )
  end

  # Handles the inspection for missing batches
  defp handle_missing_batches(state) do
    run_worker_with_conditional_rescheduling(
      state,
      :missing_batches,
      &BatchesDiscoveryTasks.inspect_for_missing/1,
      &BatchesDiscoveryTasks.missing_batches_inspection_completed?/1
    )
  end

  # Handles the discovery of historical confirmations of rollup blocks
  defp handle_historical_confirmations(state) do
    run_worker_with_conditional_rescheduling(
      state,
      :historical_confirmations,
      &ConfirmationsDiscoveryTasks.check_historical/1,
      &ConfirmationsDiscoveryTasks.historical_confirmations_discovery_completed?/1
    )
  end

  # Handles the discovery of historical L2-to-L1 message executions
  defp handle_historical_executions(state) do
    run_worker_with_conditional_rescheduling(
      state,
      :historical_executions,
      &NewL1Executions.discover_historical_l1_messages_executions/1,
      &NewL1Executions.historical_executions_discovery_completed?/1
    )
  end

  # Handles the finalization check of lifecycle transactions
  defp handle_settlement_transactions_finalization(state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    L1Finalization.monitor_lifecycle_transactions(state)

    next_run_time = now + state.intervals[:settlement_transactions_finalization]
    BufferedTask.buffer(__MODULE__, [{next_run_time, :settlement_transactions_finalization}], false)

    {:ok, state}
  end

  # Executes a worker function and conditionally reschedules the task based on its completion status.
  #
  # The worker returns `{:ok, new_state}` or `{:no_batches, new_state}`. For `:ok`,
  # the next run comes after the interval of the task. For `:no_batches`, the
  # worker waits for the first batch, and the next run comes after the interval of
  # `:new_confirmations`. Thus a task that waits does not fill the log.
  #
  # ## Parameters
  # - `state`: The current state containing completed tasks and intervals
  # - `task_tag`: The identifier of the stoppable fetcher task
  # - `worker_function`: The function to execute the task's work
  # - `completion_check_function`: The function to check if the task is completed
  #
  # ## Returns
  # - `{:ok, updated_state}` with the new state after task execution
  @spec run_worker_with_conditional_rescheduling(
          %{:completed_tasks => completion_status(), :intervals => fetcher_tasks_intervals(), optional(any()) => any()},
          stoppable_fetcher_task(),
          function(),
          function()
        ) ::
          {:ok,
           %{:completed_tasks => completion_status(), :intervals => fetcher_tasks_intervals(), optional(any()) => any()}}
  defp run_worker_with_conditional_rescheduling(
         state,
         task_tag,
         worker_function,
         completion_check_function
       ) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {status, state_after_worker_run} =
      case worker_function.(state) do
        {status, new_state} when status in [:ok, :no_batches] -> {status, new_state}
        {status, _} -> raise("Worker #{inspect(worker_function)} returned unexpected status #{inspect(status)}")
      end

    updated_state = update_completed_tasks(state_after_worker_run, task_tag, completion_check_function)

    if rescheduled?(task_tag, updated_state) do
      next_run_time = now + select_interval_by_status(status, task_tag, updated_state.intervals)
      BufferedTask.buffer(__MODULE__, [{next_run_time, task_tag}], false)
    end

    {:ok, updated_state}
  end

  # Selects the interval before the next run of a stoppable task by the status of
  # the worker. A worker that waits for the first batch runs after the interval of
  # `:new_confirmations`, which is the configured recheck interval.
  @spec select_interval_by_status(:ok | :no_batches, stoppable_fetcher_task(), fetcher_tasks_intervals()) ::
          non_neg_integer()
  defp select_interval_by_status(:ok, task_tag, intervals), do: intervals[task_tag]
  defp select_interval_by_status(:no_batches, _task_tag, intervals), do: intervals[:new_confirmations]

  # Returns true if the task should be rescheduled (not marked as completed)
  @spec rescheduled?(atom(), %{:completed_tasks => completion_status(), optional(any()) => any()}) :: boolean()
  defp rescheduled?(task_tag, state) when task_tag in @stoppable_tasks do
    not Map.get(state.completed_tasks, task_tag)
  end

  defp rescheduled?(_task_tag, _state), do: true

  # Updates the completion status of a task in the state map based on the result of a completion check function.
  @spec update_completed_tasks(
          %{:completed_tasks => completion_status(), optional(any()) => any()},
          stoppable_fetcher_task(),
          function()
        ) :: %{
          :completed_tasks => completion_status(),
          optional(any()) => any()
        }
  defp update_completed_tasks(state, task_tag, completion_check_function) do
    updated_completed_tasks = Map.put(state.completed_tasks, task_tag, completion_check_function.(state))
    %{state | completed_tasks: updated_completed_tasks}
  end
end
