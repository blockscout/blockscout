defmodule Indexer.Fetcher.Signet.OrdersFetcher do
  @moduledoc """
  Fetcher for Signet Order and Filled events from RollupOrders and HostOrders contracts.

  This module tracks cross-chain orders in the Signet protocol by:
  1. Parsing Order events from the RollupOrders contract on L2
  2. Parsing Filled events from both RollupOrders (L2) and HostOrders (L1) contracts
  3. Parsing Sweep events from RollupOrders contract
  4. Computing outputs_witness_hash for cross-chain correlation
  5. Inserting events into signet_orders / signet_fills tables

  ## Event Signatures

  RollupOrders contract:
  - Order(uint256 deadline, Input[] inputs, Output[] outputs)
  - Filled(Output[] outputs)
  - Sweep(address recipient, address token, uint256 amount)

  HostOrders contract:
  - Filled(Output[] outputs)

  ## Configuration

  The fetcher requires the following configuration in config.exs:

      config :indexer, Indexer.Fetcher.Signet.OrdersFetcher,
        enabled: true,
        rollup_orders_address: "0x...",
        host_orders_address: "0x...",
        l1_rpc: "https://...",
        l1_rpc_block_range: 1000,
        recheck_interval: 15_000

  ## Architecture

  Uses a BufferedTask-based approach similar to Arbitrum fetchers, with tasks:
  - `:check_new_rollup` - Discovers new events on rollup chain (L2)
  - `:check_new_host` - Discovers new Filled events on host chain (L1)
  - `:check_historical` - Backfills historical events
  """

  use Indexer.Fetcher, restart: :permanent

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Signet.{Order, Fill}
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Signet.{EventParser, ReorgHandler}
  alias Indexer.Helper, as: IndexerHelper

  @behaviour BufferedTask

  # Event topic hashes (keccak256 of event signatures)
  # Order(uint256,tuple[],tuple[])
  @order_event_topic "0x" <>
                       Base.encode16(
                         ExKeccak.hash_256("Order(uint256,(address,uint256)[],(address,address,uint256)[])"),
                         case: :lower
                       )

  # Filled(tuple[])
  @filled_event_topic "0x" <>
                        Base.encode16(
                          ExKeccak.hash_256("Filled((address,address,uint256)[])"),
                          case: :lower
                        )

  # Sweep(address,address,uint256)
  @sweep_event_topic "0x" <>
                       Base.encode16(
                         ExKeccak.hash_256("Sweep(address,address,uint256)"),
                         case: :lower
                       )

  # 250ms interval between processing buffered entries
  @idle_interval 250
  @max_concurrency 1
  @max_batch_size 1

  # 10 minutes cooldown for failed tasks
  @cooldown_interval :timer.minutes(10)

  # Catchup interval for historical discovery
  @catchup_recheck_interval :timer.seconds(2)

  @typep fetcher_task :: :check_new_rollup | :check_new_host | :check_historical
  @typep queued_task :: :init_worker | {non_neg_integer(), fetcher_task()}

  def child_spec([init_options, gen_server_options]) do
    {json_rpc_named_arguments, init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    config = Application.get_all_env(:indexer)[__MODULE__] || []

    rollup_orders_address = config[:rollup_orders_address]
    host_orders_address = config[:host_orders_address]
    l1_rpc = config[:l1_rpc]
    l1_rpc_block_range = config[:l1_rpc_block_range] || 1000
    recheck_interval = config[:recheck_interval] || 15_000
    start_block = config[:start_block] || 0

    failure_interval_threshold = config[:failure_interval_threshold] || min(20 * recheck_interval, :timer.minutes(10))

    intervals = %{
      check_new_rollup: recheck_interval,
      check_new_host: recheck_interval,
      check_historical: @catchup_recheck_interval
    }

    initial_config = %{
      json_l2_rpc_named_arguments: json_rpc_named_arguments,
      json_l1_rpc_named_arguments: if(l1_rpc, do: IndexerHelper.json_rpc_named_arguments(l1_rpc), else: nil),
      rollup_orders_address: rollup_orders_address,
      host_orders_address: host_orders_address,
      l1_rpc_block_range: l1_rpc_block_range,
      recheck_interval: recheck_interval,
      failure_interval_threshold: failure_interval_threshold,
      start_block: start_block
    }

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
      metadata: [fetcher: :signet_orders_fetcher]
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

    tasks_to_run =
      [{now, :check_new_rollup}]
      |> maybe_add_host_task(now, configured_state)
      |> maybe_add_historical_task(now, configured_state)

    completion_state = %{
      check_historical: is_nil(configured_state.config.start_block)
    }

    BufferedTask.buffer(__MODULE__, tasks_to_run, false)

    updated_state = Map.put(configured_state, :completed_tasks, completion_state)
    {:ok, updated_state}
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
        Logger.warning("Task #{task_tag} has been failing abnormally, applying cooldown")
        {:retry, [{new_timeout, task_tag}], state}

      {:runner_defined, nil} ->
        Logger.warning("Unknown task type: #{inspect(task_tag)}")
        {:ok, state}
    end
  end

  defp task_runners do
    %{
      check_new_rollup: &handle_check_new_rollup/1,
      check_new_host: &handle_check_new_host/1,
      check_historical: &handle_check_historical/1
    }
  end

  defp initialize_workers(state) do
    rollup_start_block = get_last_processed_block(:rollup, state.config.start_block)
    host_start_block = get_last_processed_block(:host, state.config.start_block)

    task_data = %{
      check_new_rollup: %{
        start_block: rollup_start_block
      },
      check_new_host: %{
        start_block: host_start_block
      },
      check_historical: %{
        end_block: state.config.start_block
      }
    }

    %{state | task_data: task_data}
  end

  defp maybe_add_host_task(tasks, now, state) do
    if state.config.json_l1_rpc_named_arguments && state.config.host_orders_address do
      [{now, :check_new_host} | tasks]
    else
      tasks
    end
  end

  defp maybe_add_historical_task(tasks, now, state) do
    if state.config.start_block && state.config.start_block > 0 do
      [{now, :check_historical} | tasks]
    else
      tasks
    end
  end

  defp handle_check_new_rollup(state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    case fetch_and_process_rollup_events(state) do
      {:ok, updated_state} ->
        next_run_time = now + updated_state.intervals[:check_new_rollup]
        BufferedTask.buffer(__MODULE__, [{next_run_time, :check_new_rollup}], false)
        {:ok, updated_state}

      {:error, reason} ->
        Logger.error("Failed to fetch rollup events: #{inspect(reason)}")
        {:retry, [{now + @cooldown_interval, :check_new_rollup}], state}
    end
  end

  defp handle_check_new_host(state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    case fetch_and_process_host_events(state) do
      {:ok, updated_state} ->
        next_run_time = now + updated_state.intervals[:check_new_host]
        BufferedTask.buffer(__MODULE__, [{next_run_time, :check_new_host}], false)
        {:ok, updated_state}

      {:error, reason} ->
        Logger.error("Failed to fetch host events: #{inspect(reason)}")
        {:retry, [{now + @cooldown_interval, :check_new_host}], state}
    end
  end

  defp handle_check_historical(state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    case fetch_historical_events(state) do
      {:ok, updated_state, :continue} ->
        next_run_time = now + updated_state.intervals[:check_historical]
        BufferedTask.buffer(__MODULE__, [{next_run_time, :check_historical}], false)
        {:ok, updated_state}

      {:ok, updated_state, :done} ->
        Logger.info("Historical event discovery completed")
        updated_state = put_in(updated_state.completed_tasks[:check_historical], true)
        {:ok, updated_state}

      {:error, reason} ->
        Logger.error("Failed to fetch historical events: #{inspect(reason)}")
        {:retry, [{now + @cooldown_interval, :check_historical}], state}
    end
  end

  defp fetch_and_process_rollup_events(state) do
    config = state.config
    start_block = state.task_data.check_new_rollup.start_block

    with {:ok, latest_block} <- get_latest_block(config.json_l2_rpc_named_arguments),
         {:ok, logs} <-
           fetch_logs(
             config.json_l2_rpc_named_arguments,
             config.rollup_orders_address,
             start_block,
             latest_block
           ),
         {:ok, {orders, fills}} <- EventParser.parse_rollup_logs(logs),
         :ok <- import_orders(orders),
         :ok <- import_fills(fills, :rollup) do
      Logger.info(
        "Processed rollup events: #{length(orders)} orders, #{length(fills)} fills (blocks #{start_block}-#{latest_block})"
      )

      updated_task_data = put_in(state.task_data.check_new_rollup.start_block, latest_block + 1)
      {:ok, %{state | task_data: updated_task_data}}
    end
  end

  defp fetch_and_process_host_events(state) do
    config = state.config
    start_block = state.task_data.check_new_host.start_block

    with {:ok, latest_block} <- get_latest_block(config.json_l1_rpc_named_arguments),
         end_block = min(start_block + config.l1_rpc_block_range, latest_block),
         {:ok, logs} <-
           fetch_logs(
             config.json_l1_rpc_named_arguments,
             config.host_orders_address,
             start_block,
             end_block,
             [@filled_event_topic]
           ),
         {:ok, fills} <- EventParser.parse_host_filled_logs(logs),
         :ok <- import_fills(fills, :host) do
      Logger.info(
        "Processed host events: #{length(fills)} fills (blocks #{start_block}-#{end_block})"
      )

      updated_task_data = put_in(state.task_data.check_new_host.start_block, end_block + 1)
      {:ok, %{state | task_data: updated_task_data}}
    end
  end

  defp fetch_historical_events(state) do
    config = state.config
    end_block = state.task_data.check_historical.end_block

    if end_block <= 0 do
      {:ok, state, :done}
    else
      start_block = max(0, end_block - 1000)

      with {:ok, logs} <-
             fetch_logs(
               config.json_l2_rpc_named_arguments,
               config.rollup_orders_address,
               start_block,
               end_block
             ),
           {:ok, {orders, fills}} <- EventParser.parse_rollup_logs(logs),
           :ok <- import_orders(orders),
           :ok <- import_fills(fills, :rollup) do
        Logger.info("Processed historical events: #{length(orders)} orders (blocks #{start_block}-#{end_block})")

        updated_task_data = put_in(state.task_data.check_historical.end_block, start_block - 1)
        status = if start_block <= 0, do: :done, else: :continue
        {:ok, %{state | task_data: updated_task_data}, status}
      end
    end
  end

  defp fetch_logs(json_rpc_named_arguments, contract_address, from_block, to_block, topics \\ nil) do
    topics = topics || [@order_event_topic, @filled_event_topic, @sweep_event_topic]

    request = %{
      id: 1,
      jsonrpc: "2.0",
      method: "eth_getLogs",
      params: [
        %{
          address: contract_address,
          fromBlock: "0x#{Integer.to_string(from_block, 16)}",
          toBlock: "0x#{Integer.to_string(to_block, 16)}",
          topics: [topics]
        }
      ]
    }

    case EthereumJSONRPC.json_rpc(request, json_rpc_named_arguments) do
      {:ok, logs} -> {:ok, logs}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_latest_block(json_rpc_named_arguments) do
    request = %{
      id: 1,
      jsonrpc: "2.0",
      method: "eth_blockNumber",
      params: []
    }

    case EthereumJSONRPC.json_rpc(request, json_rpc_named_arguments) do
      {:ok, hex_block} ->
        {block, ""} = Integer.parse(String.trim_leading(hex_block, "0x"), 16)
        {:ok, block}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_last_processed_block(chain_type, default_start) do
    # Query database for last processed block
    # Falls back to default_start if no records exist
    case chain_type do
      :rollup ->
        case Explorer.Repo.one(
               from(o in Order,
                 select: max(o.block_number)
               )
             ) do
          nil -> default_start
          block -> block + 1
        end

      :host ->
        case Explorer.Repo.one(
               from(f in Fill,
                 where: f.chain_type == :host,
                 select: max(f.block_number)
               )
             ) do
          nil -> default_start
          block -> block + 1
        end
    end
  end

  defp import_orders([]), do: :ok

  defp import_orders(orders) do
    {:ok, _} =
      Chain.import(%{
        signet_orders: %{params: orders},
        timeout: :infinity
      })

    :ok
  end

  defp import_fills([], _chain_type), do: :ok

  defp import_fills(fills, chain_type) do
    fills_with_chain = Enum.map(fills, &Map.put(&1, :chain_type, chain_type))

    {:ok, _} =
      Chain.import(%{
        signet_fills: %{params: fills_with_chain},
        timeout: :infinity
      })

    :ok
  end

  @doc """
  Handle chain reorganization by removing events from invalidated blocks.

  Called when a reorg is detected to clean up data from blocks that are
  no longer in the canonical chain.
  """
  @spec handle_reorg(non_neg_integer(), :rollup | :host) :: :ok
  def handle_reorg(from_block, chain_type) do
    ReorgHandler.handle_reorg(from_block, chain_type)
  end
end
