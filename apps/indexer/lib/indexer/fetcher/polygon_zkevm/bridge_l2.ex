defmodule Indexer.Fetcher.PolygonZkevm.BridgeL2 do
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
  alias Explorer.Repo
  alias Indexer.Fetcher.PolygonZkevm.BridgeL1
  alias Indexer.Helper

  @eth_get_logs_range_size 1000
  @fetcher_name :polygon_zkevm_bridge_l2

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
  def init(args) do
    json_rpc_named_arguments = args[:json_rpc_named_arguments]
    {:ok, %{}, {:continue, json_rpc_named_arguments}}
  end

  @impl GenServer
  def handle_continue(json_rpc_named_arguments, _state) do
    Logger.metadata(fetcher: @fetcher_name)
    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    Process.send_after(self(), :init_with_delay, 2000)
    {:noreply, %{json_rpc_named_arguments: json_rpc_named_arguments}}
  end

  @impl GenServer
  def handle_info(:init_with_delay, %{json_rpc_named_arguments: json_rpc_named_arguments} = state) do
    env = Application.get_all_env(:indexer)[__MODULE__]
    env_l1 = Application.get_all_env(:indexer)[BridgeL1]

    with {:start_block_undefined, false} <- {:start_block_undefined, is_nil(env[:start_block])},
         rpc_l1 = env_l1[:rpc],
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(rpc_l1)},
         {:rollup_network_id_l1_is_valid, true} <-
           {:rollup_network_id_l1_is_valid,
            !is_nil(env_l1[:rollup_network_id_l1]) and env_l1[:rollup_network_id_l1] >= 0},
         {:rollup_network_id_l2_is_valid, true} <-
           {:rollup_network_id_l2_is_valid, !is_nil(env[:rollup_network_id_l2]) and env[:rollup_network_id_l2] > 0},
         {:rollup_index_l2_undefined, false} <- {:rollup_index_l2_undefined, is_nil(env[:rollup_index_l2])},
         {:bridge_contract_address_is_valid, true} <-
           {:bridge_contract_address_is_valid, Helper.address_correct?(env[:bridge_contract])},
         start_block = parse_integer(env[:start_block]),
         false <- is_nil(start_block),
         true <- start_block > 0,
         {last_l2_block_number, last_l2_transaction_hash} = Reader.last_l2_item(),
         {:ok, latest_block} =
           Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, Helper.infinite_retries_number()),
         {:start_block_valid, true} <-
           {:start_block_valid,
            (start_block <= last_l2_block_number || last_l2_block_number == 0) && start_block <= latest_block},
         {:ok, last_l2_transaction} <-
           Helper.get_transaction_by_hash(last_l2_transaction_hash, json_rpc_named_arguments),
         {:l2_transaction_not_found, false} <-
           {:l2_transaction_not_found, !is_nil(last_l2_transaction_hash) && is_nil(last_l2_transaction)} do
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         bridge_contract: env[:bridge_contract],
         json_rpc_named_arguments: json_rpc_named_arguments,
         json_rpc_named_arguments_l1: Helper.json_rpc_named_arguments(rpc_l1),
         end_block: latest_block,
         start_block: max(start_block, last_l2_block_number),
         rollup_network_id_l1: env_l1[:rollup_network_id_l1],
         rollup_network_id_l2: env[:rollup_network_id_l2],
         rollup_index_l1: env_l1[:rollup_index_l1],
         rollup_index_l2: env[:rollup_index_l2]
       }}
    else
      {:start_block_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, state}

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        {:stop, :normal, state}

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
        {:stop, :normal, state}

      {:start_block_valid, false} ->
        Logger.error("Invalid L2 Start Block value. Please, check the value and polygon_zkevm_bridge table.")
        {:stop, :normal, state}

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L2 transaction from RPC by its hash or latest block due to RPC error: #{inspect(error_data)}"
        )

        {:stop, :normal, state}

      {:l2_transaction_not_found, true} ->
        Logger.error(
          "Cannot find last L2 transaction from RPC by its hash. Probably, there was a reorg on L2 chain. Please, check polygon_zkevm_bridge table."
        )

        {:stop, :normal, state}

      _ ->
        Logger.error("L2 Start Block is invalid or zero.")
        {:stop, :normal, state}
    end
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          bridge_contract: bridge_contract,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments,
          json_rpc_named_arguments_l1: json_rpc_named_arguments_l1,
          rollup_network_id_l1: rollup_network_id_l1,
          rollup_network_id_l2: rollup_network_id_l2,
          rollup_index_l1: rollup_index_l1,
          rollup_index_l2: rollup_index_l2
        } = state
      ) do
    start_block..end_block
    |> Enum.chunk_every(@eth_get_logs_range_size)
    |> Enum.each(fn current_chunk ->
      chunk_start = List.first(current_chunk)
      chunk_end = List.last(current_chunk)

      if chunk_start <= chunk_end do
        Helper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, :L2)

        operations =
          {chunk_start, chunk_end}
          |> get_logs_all(bridge_contract, json_rpc_named_arguments)
          |> prepare_operations(
            rollup_network_id_l1,
            rollup_network_id_l2,
            rollup_index_l1,
            rollup_index_l2,
            json_rpc_named_arguments,
            json_rpc_named_arguments_l1
          )

        import_operations(operations)

        Helper.log_blocks_chunk_handling(
          chunk_start,
          chunk_end,
          start_block,
          end_block,
          "#{Enum.count(operations)} L2 operation(s)",
          :L2
        )
      end
    end)

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  def reorg_handle(reorg_block) do
    {deleted_count, _} =
      Repo.delete_all(from(b in Bridge, where: b.type == :withdrawal and b.block_number >= ^reorg_block))

    if deleted_count > 0 do
      Logger.warning(
        "As L2 reorg was detected, some withdrawals with block_number >= #{reorg_block} were removed from polygon_zkevm_bridge table. Number of removed rows: #{deleted_count}."
      )
    end
  end
end
