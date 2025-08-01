defmodule Indexer.Fetcher.PolygonZkevm.BridgeL1 do
  @moduledoc """
  Fills polygon_zkevm_bridge DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query
  import Explorer.Helper, only: [parse_integer: 1]

  import Indexer.Fetcher.PolygonZkevm.Bridge,
    only: [get_logs_all: 3, import_operations: 1, prepare_operations: 7]

  alias Explorer.Chain.PolygonZkevm.{Bridge, Reader}
  alias Explorer.Chain.RollupReorgMonitorQueue
  alias Explorer.Repo
  alias Indexer.Fetcher.RollupL1ReorgMonitor
  alias Indexer.Helper

  @eth_get_logs_range_size 1000
  @fetcher_name :polygon_zkevm_bridge_l1

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_args) do
    {:ok, %{}, {:continue, :ok}}
  end

  @impl GenServer
  def handle_continue(_, state) do
    Logger.metadata(fetcher: @fetcher_name)
    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    Process.send_after(self(), :init_with_delay, 2000)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:init_with_delay, _state) do
    env = Application.get_all_env(:indexer)[__MODULE__]
    env_l2 = Application.get_all_env(:indexer)[Indexer.Fetcher.PolygonZkevm.BridgeL2]

    with {:start_block_undefined, false} <- {:start_block_undefined, is_nil(env[:start_block])},
         _ <- RollupL1ReorgMonitor.wait_for_start(__MODULE__),
         rpc = env[:rpc],
         {:rpc_undefined, false} <- {:rpc_undefined, is_nil(rpc)},
         {:rollup_network_id_l1_is_valid, true} <-
           {:rollup_network_id_l1_is_valid, !is_nil(env[:rollup_network_id_l1]) and env[:rollup_network_id_l1] >= 0},
         {:rollup_network_id_l2_is_valid, true} <-
           {:rollup_network_id_l2_is_valid,
            !is_nil(env_l2[:rollup_network_id_l2]) and env_l2[:rollup_network_id_l2] > 0},
         {:rollup_index_l2_undefined, false} <- {:rollup_index_l2_undefined, is_nil(env_l2[:rollup_index_l2])},
         {:bridge_contract_address_is_valid, true} <-
           {:bridge_contract_address_is_valid, Helper.address_correct?(env[:bridge_contract])},
         start_block = parse_integer(env[:start_block]),
         false <- is_nil(start_block),
         true <- start_block > 0,
         {last_l1_block_number, last_l1_transaction_hash} = Reader.last_l1_item(),
         json_rpc_named_arguments = Helper.json_rpc_named_arguments(rpc),
         {:ok, block_check_interval, safe_block} <- Helper.get_block_check_interval(json_rpc_named_arguments),
         {:start_block_valid, true, _, _} <-
           {:start_block_valid,
            (start_block <= last_l1_block_number || last_l1_block_number == 0) && start_block <= safe_block,
            last_l1_block_number, safe_block},
         {:ok, last_l1_transaction} <-
           Helper.get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments),
         {:l1_transaction_not_found, false} <-
           {:l1_transaction_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_transaction)} do
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         block_check_interval: block_check_interval,
         bridge_contract: env[:bridge_contract],
         json_rpc_named_arguments: json_rpc_named_arguments,
         end_block: safe_block,
         start_block: max(start_block, last_l1_block_number),
         rollup_network_id_l1: env[:rollup_network_id_l1],
         rollup_network_id_l2: env_l2[:rollup_network_id_l2],
         rollup_index_l1: env[:rollup_index_l1],
         rollup_index_l2: env_l2[:rollup_index_l2]
       }}
    else
      {:start_block_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, %{}}

      {:rpc_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        {:stop, :normal, %{}}

      {:rollup_network_id_l1_is_valid, false} ->
        Logger.error(
          "Invalid network ID for L1. Please, check INDEXER_POLYGON_ZKEVM_L1_BRIDGE_NETWORK_ID env variable."
        )

        {:stop, :normal, %{}}

      {:rollup_network_id_l2_is_valid, false} ->
        Logger.error(
          "Invalid network ID for L2. Please, check INDEXER_POLYGON_ZKEVM_L2_BRIDGE_NETWORK_ID env variable."
        )

        {:stop, :normal, %{}}

      {:rollup_index_l2_undefined, true} ->
        Logger.error(
          "Rollup index is undefined for L2. Please, check INDEXER_POLYGON_ZKEVM_L2_BRIDGE_ROLLUP_INDEX env variable."
        )

        {:stop, :normal, %{}}

      {:bridge_contract_address_is_valid, false} ->
        Logger.error("PolygonZkEVMBridge contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:start_block_valid, false, last_l1_block_number, safe_block} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and polygon_zkevm_bridge table.")
        Logger.error("last_l1_block_number = #{inspect(last_l1_block_number)}")
        Logger.error("safe_block = #{inspect(safe_block)}")
        {:stop, :normal, %{}}

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L1 transaction from RPC by its hash, latest block, or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )

        {:stop, :normal, %{}}

      {:l1_transaction_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check polygon_zkevm_bridge table."
        )

        {:stop, :normal, %{}}

      _ ->
        Logger.error("L1 Start Block is invalid or zero.")
        {:stop, :normal, %{}}
    end
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          bridge_contract: bridge_contract,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments,
          rollup_network_id_l1: rollup_network_id_l1,
          rollup_network_id_l2: rollup_network_id_l2,
          rollup_index_l1: rollup_index_l1,
          rollup_index_l2: rollup_index_l2
        } = state
      ) do
    time_before = Timex.now()

    last_written_block =
      start_block..end_block
      |> Enum.chunk_every(@eth_get_logs_range_size)
      |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
        chunk_start = List.first(current_chunk)
        chunk_end = List.last(current_chunk)

        if chunk_start <= chunk_end do
          Helper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, :L1)

          operations =
            {chunk_start, chunk_end}
            |> get_logs_all(bridge_contract, json_rpc_named_arguments)
            |> prepare_operations(
              rollup_network_id_l1,
              rollup_network_id_l2,
              rollup_index_l1,
              rollup_index_l2,
              json_rpc_named_arguments,
              json_rpc_named_arguments
            )

          import_operations(operations)

          Helper.log_blocks_chunk_handling(
            chunk_start,
            chunk_end,
            start_block,
            end_block,
            "#{Enum.count(operations)} L1 operation(s)",
            :L1
          )
        end

        reorg_block = RollupReorgMonitorQueue.reorg_block_pop(__MODULE__)

        if !is_nil(reorg_block) && reorg_block > 0 do
          reorg_handle(reorg_block)
          {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
        else
          {:cont, chunk_end}
        end
      end)

    new_start_block = last_written_block + 1

    {:ok, new_end_block} =
      Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, Helper.infinite_retries_number())

    delay =
      if new_end_block == last_written_block do
        # there is no new block, so wait for some time to let the chain issue the new block
        max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0)
      else
        0
      end

    Process.send_after(self(), :continue, delay)

    {:noreply, %{state | start_block: new_start_block, end_block: new_end_block}}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @doc """
    Returns L1 RPC URL for this module.
  """
  @spec l1_rpc_url() :: binary()
  def l1_rpc_url do
    Application.get_all_env(:indexer)[__MODULE__][:rpc]
  end

  @doc """
    Determines if `Indexer.Fetcher.RollupL1ReorgMonitor` module must be up
    for this module.

    ## Returns
    - `true` if the reorg monitor must be active, `false` otherwise.
  """
  @spec requires_l1_reorg_monitor?() :: boolean()
  def requires_l1_reorg_monitor? do
    module_config = Application.get_all_env(:indexer)[__MODULE__]
    not is_nil(module_config[:start_block])
  end

  defp reorg_handle(reorg_block) do
    {deleted_count, _} =
      Repo.delete_all(from(b in Bridge, where: b.type == :deposit and b.block_number >= ^reorg_block))

    if deleted_count > 0 do
      Logger.warning(
        "As L1 reorg was detected, some deposits with block_number >= #{reorg_block} were removed from polygon_zkevm_bridge table. Number of removed rows: #{deleted_count}."
      )
    end
  end
end
