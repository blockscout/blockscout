defmodule Indexer.Fetcher.Arbitrum.TrackingMessagesOnL1 do
  @moduledoc """
  Tracks Arbitrum L1→L2 bridge messages with BufferedTask. Runs a live loop for new
  messages and a catchup loop for historical messages that stops once the rollup
  init block is reached. Uses separate recheck intervals for live and catchup work
  and a failure threshold to guard stuck executions.
  """

  use Indexer.Fetcher, restart: :permanent

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1]

  alias EthereumJSONRPC.Arbitrum, as: ArbitrumRpc
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Fetcher.Arbitrum.Workers.NewMessagesToL2
  alias Indexer.Helper, as: IndexerHelper

  @behaviour BufferedTask

  @idle_interval 250
  @max_concurrency 1
  @max_batch_size 1
  @cooldown_interval :timer.minutes(10)
  @catchup_recheck_interval :timer.seconds(2)

  @stoppable_tasks [:check_historical]

  @typep fetcher_task :: :check_new | :check_historical
  @typep queued_task :: :init_worker | {non_neg_integer(), fetcher_task()}
  @typep fetcher_tasks_intervals :: %{fetcher_task() => non_neg_integer()}
  @typep completion_status :: %{fetcher_task() => boolean()}

  def child_spec([init_options, gen_server_options]) do
    {json_rpc_named_arguments, init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
    l1_rpc = config_common[:l1_rpc]
    l1_rpc_block_range = config_common[:l1_rpc_block_range]
    l1_rollup_address = config_common[:l1_rollup_address]
    l1_rollup_init_block = config_common[:l1_rollup_init_block]
    l1_start_block = config_common[:l1_start_block]
    l1_rpc_chunk_size = config_common[:l1_rpc_chunk_size]

    config_tracker = Application.get_all_env(:indexer)[__MODULE__]
    recheck_interval = config_tracker[:recheck_interval]

    failure_interval_threshold =
      config_tracker[:failure_interval_threshold] || min(20 * recheck_interval, :timer.minutes(10))

    intervals = %{
      check_new: recheck_interval,
      check_historical: @catchup_recheck_interval
    }

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
      catchup_recheck_interval: @catchup_recheck_interval
    }

    initial_state = %{
      config: initial_config,
      intervals: intervals,
      task_data: %{},
      completed_tasks: %{check_historical: false}
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

  def run([:init_worker], state) do
    configured_state = initialize_workers(state)
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    BufferedTask.buffer(__MODULE__, [{now, :check_new}, {now, :check_historical}], false)

    {:ok, configured_state}
  end

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
      check_historical: &handle_check_historical/1
    }
  end

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
    new_msg_to_l2_start_block = DbMessages.l1_block_to_discover_latest_message_to_l2(l1_start_block)
    historical_msg_to_l2_end_block = DbMessages.l1_block_to_discover_earliest_message_to_l2(l1_start_block - 1)

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
      }
    }

    %{state | config: updated_config, task_data: task_data}
  end

  defp handle_check_new(state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok, end_block} = NewMessagesToL2.discover_new_messages_to_l2(state)

    updated_state =
      state
      |> ArbitrumHelper.update_fetcher_task_data(:check_new, %{start_block: end_block + 1})

    next_run_time = now + updated_state.intervals[:check_new]
    BufferedTask.buffer(__MODULE__, [{next_run_time, :check_new}], false)

    {:ok, updated_state}
  end

  defp handle_check_historical(state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok, start_block} = NewMessagesToL2.discover_historical_messages_to_l2(state)

    updated_state =
      state
      |> ArbitrumHelper.update_fetcher_task_data(:check_historical, %{end_block: start_block - 1})
      |> then(&update_completed_tasks(&1, :check_historical, historical_catchup_completed?(&1)))

    if rescheduled?(:check_historical, updated_state) do
      next_run_time = now + updated_state.intervals[:check_historical]
      BufferedTask.buffer(__MODULE__, [{next_run_time, :check_historical}], false)
    end

    {:ok, updated_state}
  end

  defp historical_catchup_completed?(%{
         config: %{l1_rollup_init_block: l1_rollup_init_block},
         task_data: %{check_historical: %{end_block: end_block}}
       }) do
    end_block < l1_rollup_init_block
  end

  defp rescheduled?(task_tag, state) when task_tag in @stoppable_tasks do
    not Map.get(state.completed_tasks, task_tag)
  end

  defp rescheduled?(_task_tag, _state), do: true

  defp update_completed_tasks(state, task_tag, completed?) do
    %{state | completed_tasks: Map.put(state.completed_tasks, task_tag, completed?)}
  end
end
