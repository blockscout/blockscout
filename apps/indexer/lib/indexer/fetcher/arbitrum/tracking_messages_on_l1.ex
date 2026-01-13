defmodule Indexer.Fetcher.Arbitrum.TrackingMessagesOnL1 do
  @moduledoc """
    Manages the tracking and processing of new and historical cross-chain messages initiated on L1 for an Arbitrum rollup.

    This module is responsible for continuously monitoring and importing new messages
    initiated from Layer 1 (L1) to Arbitrum's Layer 2 (L2), as well as discovering
    and processing historical messages that were sent previously but have not yet
    been imported into the database.

    The fetcher uses a BufferedTask-based approach for task scheduling, where each
    type of task is scheduled independently with appropriate intervals. This provides
    better error isolation and task management.

    Task types include:
    - `:check_new`: Discovers new L1-to-L2 messages appearing on L1 as the blockchain
      progresses. This task runs continuously with a configurable recheck interval.
    - `:check_historical`: Retrieves historical L1-to-L2 messages that were missed
      if the message synchronization process did not start from the Arbitrum rollup's
      inception. This task walks backward from the current block until it reaches the
      rollup initialization block, at which point it stops scheduling itself.
    - `:check_missing_origination`: Discovers L1-to-L2 messages that have completion
      information on L2 but are missing origination transaction details from L1. This
      task works backward from the most recent fully indexed message in configurable
      ranges, filling gaps where L2 indexing ran ahead of L1 event discovery.

    Task scheduling behavior:
    The `:check_new` task runs continuously with a standard recheck interval, while
    the `:check_historical` and `:check_missing_origination` tasks use a shorter
    catchup interval (2 seconds) to expedite backfilling. Once a catchup task
    completes (historical reaches the rollup init block, missing origination reaches
    the earliest discovered message), it is no longer scheduled.

    Tasks that fail abnormally within a configurable threshold period will enter a
    cooldown state for 10 minutes to prevent resource exhaustion.

    Initialization architecture:
    The module uses a two-phase initialization process:
    1. Static configuration in `child_spec`:
       - L1 RPC parameters and rollup addresses
       - Recheck intervals for live and catchup work
       - Failure threshold for cooldown triggering
    2. Dynamic initialization in `init/3`:
       - Queries the L1 bridge address from the RPC
       - Determines initial cursors from the database and L1 network state
       - Prepares the task_data map with both `:check_new` and `:check_historical`
         cursors

    Discovery of L1-to-L2 messages is executed by requesting logs on L1 that
    correspond to the `MessageDelivered` event emitted by the Arbitrum bridge
    contract. Cross-chain messages are composed of information from the logs' data
    as well as from the corresponding transaction details. To get the transaction
    details, RPC calls `eth_getTransactionByHash` are made in chunks.
  """

  use Indexer.Fetcher, restart: :permanent

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1, log_warning: 1]

  alias EthereumJSONRPC.Arbitrum, as: ArbitrumRpc
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Fetcher.Arbitrum.Workers.NewMessagesToL2
  alias Indexer.Helper, as: IndexerHelper

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

  # Catchup task (historical messages discovery) needs to run as quickly as possible
  # since it is only needed when indexing a rollup chain that already has many blocks.
  # This interval is hardcoded since these tasks should complete rapidly and don't need
  # to be configurable.
  @catchup_recheck_interval :timer.seconds(2)

  @stoppable_tasks [:check_historical, :check_missing_origination]

  @typep fetcher_task :: :check_new | :check_historical | :check_missing_origination
  @typep rescheduled_tasks :: :check_historical | :check_missing_origination
  @typep queued_task :: :init_worker | {non_neg_integer(), fetcher_task()}
  @typep completion_status :: %{rescheduled_tasks() => boolean()}
  @typep fetcher_tasks_data :: %{fetcher_task() => map()}

  # Creates a child specification for the BufferedTask supervisor. Extracts and merges
  # configuration from application environment, sets up task intervals, initializes
  # RPC configurations for parent and rollup chains, and creates the initial state
  # with task scheduling parameters. Returns a transient supervisor child spec with
  # the configured BufferedTask.
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

    config_tracker = Application.get_all_env(:indexer)[__MODULE__]
    recheck_interval = config_tracker[:recheck_interval]
    missed_message_ids_range = config_tracker[:missed_message_ids_range]

    failure_interval_threshold =
      config_tracker[:failure_interval_threshold] || min(20 * recheck_interval, :timer.minutes(10))

    # Configure intervals for each task type
    intervals = %{
      check_new: recheck_interval,
      check_historical: @catchup_recheck_interval,
      check_missing_origination: @catchup_recheck_interval
    }

    # Set up initial configuration structure
    initial_config = %{
      json_l1_rpc_named_arguments: IndexerHelper.json_rpc_named_arguments(l1_rpc),
      json_l2_rpc_named_arguments: json_rpc_named_arguments,
      l1_rpc_block_range: l1_rpc_block_range,
      l1_rpc_chunk_size: l1_rpc_chunk_size,
      l1_rollup_address: l1_rollup_address,
      l1_start_block: l1_start_block,
      l1_rollup_init_block: l1_rollup_init_block,
      recheck_interval: recheck_interval,
      failure_interval_threshold: failure_interval_threshold,
      catchup_recheck_interval: @catchup_recheck_interval,
      missed_message_ids_range: missed_message_ids_range
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

    Supervisor.child_spec(
      {BufferedTask, [{__MODULE__, buffered_task_init_options}, gen_server_options]},
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
      metadata: [fetcher: :arbitrum_l1_messages_tracker]
    ]
  end

  @impl BufferedTask
  def init(initial, reducer, _state) do
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

    # Define all possible tasks with their initial timestamps
    default_tasks_to_run = [
      {now, :check_new},
      {now, :check_historical},
      {now, :check_missing_origination}
    ]

    # Define default completion state for stoppable tasks
    default_completion_state = %{
      check_historical: false,
      check_missing_origination: false
    }

    # Apply conditional disabling logic
    {tasks_to_run, completion_state} =
      {default_tasks_to_run, default_completion_state}
      |> maybe_disable_check_missing_origination(configured_state)

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
        {:retry, [{timeout, task_tag}], state}

      {:threshold_ok, false} ->
        new_timeout = now + @cooldown_interval

        log_warning(
          "Task #{task_tag} has been failing abnormally, applying cooldown for #{div(@cooldown_interval, 1000)} seconds"
        )

        {:retry, [{new_timeout, task_tag}], state}

      {:runner_defined, nil} ->
        log_warning("Unknown task type: #{inspect(task_tag)}")
        {:ok, state}
    end
  end

  defp task_runners do
    %{
      check_new: &handle_check_new/1,
      check_historical: &handle_check_historical/1,
      check_missing_origination: &handle_check_missing_origination/1
    }
  end

  # Initializes the worker state with contract addresses and block information
  @spec initialize_workers(%{
          :config => map(),
          optional(any()) => any()
        }) :: %{:config => map(), :task_data => fetcher_tasks_data(), optional(any()) => any()}
  defp initialize_workers(state) do
    json_l1_rpc_named_arguments = state.config.json_l1_rpc_named_arguments
    l1_rollup_address = state.config.l1_rollup_address

    %{bridge: bridge_address} =
      ArbitrumRpc.get_contracts_for_rollup(
        l1_rollup_address,
        :bridge,
        json_l1_rpc_named_arguments
      )

    l1_start_block = Rpc.get_l1_start_block(state.config.l1_start_block, json_l1_rpc_named_arguments)

    {safe_l1_block, _latest_l1_block} =
      Rpc.get_safe_and_latest_l1_blocks(json_l1_rpc_named_arguments, state.config.l1_rpc_block_range)

    new_msg_to_l2_start_block = DbMessages.l1_block_to_discover_latest_message_to_l2(l1_start_block)

    %{
      l1_block_to_discover_earlier_messages: historical_msg_to_l2_end_block,
      already_discovered_message_id: earliest_discovered_msg_id
    } = DbMessages.inspect_earliest_discovered_message_to_l2(l1_start_block - 1)

    highest_safe_fully_indexed_msg_id =
      DbMessages.highest_safe_fully_indexed_message_to_l2(safe_l1_block, nil)

    updated_config =
      Map.merge(state.config, %{
        l1_start_block: l1_start_block,
        l1_bridge_address: bridge_address
      })

    task_data = %{
      check_new: %{
        start_block: new_msg_to_l2_start_block
      },
      check_historical: %{
        end_block: historical_msg_to_l2_end_block
      },
      check_missing_origination: %{
        end_message_id:
          if(is_nil(highest_safe_fully_indexed_msg_id), do: nil, else: highest_safe_fully_indexed_msg_id - 1),
        earliest_discovered_message_id: earliest_discovered_msg_id || 0,
        safe_l1_block: safe_l1_block
      }
    }

    %{state | config: updated_config, task_data: task_data}
  end

  # Conditionally disables missing origination discovery based on whether there
  # are any fully indexed messages to work backward from. If `end_message_id` in
  # the task data is nil, it means no fully indexed messages exist yet, so there's
  # nothing to backfill and the task is disabled.
  @spec maybe_disable_check_missing_origination({[queued_task()], completion_status()}, %{
          :task_data => %{
            :check_missing_origination => %{
              :end_message_id => non_neg_integer() | nil,
              optional(any()) => any()
            },
            optional(any()) => any()
          },
          optional(any()) => any()
        }) :: {[queued_task()], completion_status()}
  defp maybe_disable_check_missing_origination({tasks, completion}, state) do
    if is_nil(state.task_data.check_missing_origination.end_message_id) do
      log_info("Missing origination discovery is disabled (no fully indexed messages found)")
      {delete_task_by_tag(tasks, :check_missing_origination), %{completion | check_missing_origination: true}}
    else
      {tasks, completion}
    end
  end

  # Helper to remove a task from the tasks list by its tag
  @spec delete_task_by_tag([queued_task()], fetcher_task()) :: [queued_task()]
  defp delete_task_by_tag(tasks, tag) do
    Enum.reject(tasks, fn
      {_timeout, task_tag} -> task_tag == tag
      _other -> false
    end)
  end

  # Handles the discovery of new L1-to-L2 messages
  defp handle_check_new(state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok, updated_state} = NewMessagesToL2.check_new(state)

    next_run_time = now + updated_state.intervals[:check_new]
    BufferedTask.buffer(__MODULE__, [{next_run_time, :check_new}], false)

    {:ok, updated_state}
  end

  # Handles the discovery of historical L1-to-L2 messages
  defp handle_check_historical(state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok, updated_state} = NewMessagesToL2.check_historical(state)

    if rescheduled?(:check_historical, updated_state) do
      next_run_time = now + updated_state.intervals[:check_historical]
      BufferedTask.buffer(__MODULE__, [{next_run_time, :check_historical}], false)
    end

    {:ok, updated_state}
  end

  # Handles the discovery of L1-to-L2 messages that have completion information
  # but are missing origination transaction details.
  #
  # This function works backward from the most recent fully indexed message,
  # checking ranges of message IDs for those that have been relayed on L2 but
  # lack L1 origination data. It stops when reaching the earliest discovered
  # message ID that was captured during initialization.
  #
  # The function retrieves the current safe L1 block, then calls the worker
  # module to perform the actual discovery and import. Based on the worker's
  # response, it either schedules the next iteration or marks the task as
  # complete.
  #
  # ## Parameters
  # - `state`: Current fetcher state containing configuration, task data, and
  #   completion tracking.
  #
  # ## Returns
  # - `{:ok, updated_state}` where the state includes:
  #   - Updated `task_data.check_missing_origination.end_message_id` cursor
  #   - Updated `completed_tasks.check_missing_origination` flag
  defp handle_check_missing_origination(state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok, updated_state} = NewMessagesToL2.check_missing_origination(state)

    if rescheduled?(:check_missing_origination, updated_state) do
      next_run_time = now + updated_state.intervals[:check_missing_origination]
      BufferedTask.buffer(__MODULE__, [{next_run_time, :check_missing_origination}], false)
    end

    {:ok, updated_state}
  end

  # Returns true if the task should be rescheduled (not marked as completed)
  @spec rescheduled?(atom(), %{:completed_tasks => completion_status(), optional(any()) => any()}) :: boolean()
  defp rescheduled?(task_tag, state) when task_tag in @stoppable_tasks do
    not Map.get(state.completed_tasks, task_tag)
  end

  defp rescheduled?(_task_tag, _state), do: true
end
