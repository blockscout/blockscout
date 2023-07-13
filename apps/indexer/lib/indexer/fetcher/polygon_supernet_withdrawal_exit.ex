defmodule Indexer.Fetcher.PolygonSupernetWithdrawalExit do
  @moduledoc """
  Fills polygon_supernet_withdrawal_exits DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [parse_integer: 1]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.PolygonSupernetWithdrawalExit
  alias Indexer.Fetcher.PolygonSupernet
  alias Indexer.Helper

  @fetcher_name :polygon_supernet_withdrawal_exit

  # 32-byte signature of the event ExitProcessed(uint256 indexed id, bool indexed success, bytes returnData)
  @exit_processed_event "0x8bbfa0c9bee3785c03700d2a909592286efb83fc7e7002be5764424b9842f7ec"

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
    Logger.metadata(fetcher: @fetcher_name)

    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         {:reorg_monitor_started, true} <-
           {:reorg_monitor_started, !is_nil(Process.whereis(Indexer.Fetcher.PolygonSupernet))},
         polygon_supernet_l1_rpc =
           Application.get_all_env(:indexer)[Indexer.Fetcher.PolygonSupernet][:polygon_supernet_l1_rpc],
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(polygon_supernet_l1_rpc)},
         {:contract_is_valid, true} <- {:contract_is_valid, Helper.is_address_correct?(env[:exit_helper])},
         start_block_l1 = parse_integer(env[:start_block_l1]),
         false <- is_nil(start_block_l1),
         true <- start_block_l1 > 0,
         {last_l1_block_number, last_l1_transaction_hash} <- get_last_l1_item(),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
         json_rpc_named_arguments = PolygonSupernet.json_rpc_named_arguments(polygon_supernet_l1_rpc),
         {:ok, last_l1_tx} <-
           PolygonSupernet.get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments),
         {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_tx)},
         {:ok, block_check_interval, last_safe_block} <-
           PolygonSupernet.get_block_check_interval(json_rpc_named_arguments) do
      start_block = max(start_block_l1, last_l1_block_number)

      Subscriber.to(:polygon_supernet_reorg_block, :realtime)

      Process.send(self(), :continue, [])

      {:ok,
       %{
         exit_helper: env[:exit_helper],
         block_check_interval: block_check_interval,
         start_block: start_block,
         end_block: last_safe_block,
         json_rpc_named_arguments: json_rpc_named_arguments
       }}
    else
      {:start_block_l1_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        :ignore

      {:reorg_monitor_started, false} ->
        Logger.error("Cannot start this process as reorg monitor in Indexer.Fetcher.PolygonSupernet is not started.")
        :ignore

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        :ignore

      {:contract_is_valid, false} ->
        Logger.error("Exit Helper contract address is invalid or not defined.")
        :ignore

      {:start_block_l1_valid, false} ->
        Logger.error(
          "Invalid L1 Start Block value. Please, check the value and polygon_supernet_withdrawal_exits table."
        )

        :ignore

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L1 transaction from RPC by its hash, last safe block, or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )

        :ignore

      {:l1_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check polygon_supernet_withdrawal_exits table."
        )

        :ignore

      _ ->
        Logger.error("Withdrawals L1 Start Block is invalid or zero.")
        :ignore
    end
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          exit_helper: exit_helper,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    time_before = Timex.now()

    chunks_number = ceil((end_block - start_block + 1) / PolygonSupernet.get_logs_range_size())
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    last_written_block =
      chunk_range
      |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
        chunk_start = start_block + PolygonSupernet.get_logs_range_size() * current_chunk
        chunk_end = min(chunk_start + PolygonSupernet.get_logs_range_size() - 1, end_block)

        if chunk_end >= chunk_start do
          PolygonSupernet.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, "L1")

          {:ok, result} =
            PolygonSupernet.get_logs(
              chunk_start,
              chunk_end,
              exit_helper,
              @exit_processed_event,
              json_rpc_named_arguments,
              100_000_000
            )

          withdrawal_exits = prepare_exits(result)

          {:ok, _} =
            Chain.import(%{
              polygon_supernet_withdrawal_exits: %{params: withdrawal_exits},
              timeout: :infinity
            })

          PolygonSupernet.log_blocks_chunk_handling(
            chunk_start,
            chunk_end,
            start_block,
            end_block,
            "#{Enum.count(withdrawal_exits)} ExitProcessed event(s)",
            "L1"
          )
        end

        reorg_block = PolygonSupernet.reorg_block_pop(@fetcher_name)

        if !is_nil(reorg_block) && reorg_block > 0 do
          {deleted_count, _} =
            Repo.delete_all(from(we in PolygonSupernetWithdrawalExit, where: we.l1_block_number >= ^reorg_block))

          log_deleted_rows_count(reorg_block, deleted_count)

          {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
        else
          {:cont, chunk_end}
        end
      end)

    new_start_block = last_written_block + 1
    {:ok, new_end_block} = PolygonSupernet.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

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
  def handle_info({:chain_event, :polygon_supernet_reorg_block, :realtime, block_number}, state) do
    PolygonSupernet.reorg_block_push(@fetcher_name, block_number)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp log_deleted_rows_count(reorg_block, count) do
    if count > 0 do
      Logger.warning(
        "As L1 reorg was detected, all rows with l1_block_number >= #{reorg_block} were removed from the polygon_supernet_withdrawal_exits table. Number of removed rows: #{count}."
      )
    end
  end

  defp prepare_exits(events) do
    Enum.map(events, fn event ->
      %{
        msg_id: quantity_to_integer(Enum.at(event["topics"], 1)),
        l1_transaction_hash: event["transactionHash"],
        l1_block_number: quantity_to_integer(event["blockNumber"]),
        success: quantity_to_integer(Enum.at(event["topics"], 2)) != 0
      }
    end)
  end

  defp get_last_l1_item do
    query =
      from(we in PolygonSupernetWithdrawalExit,
        select: {we.l1_block_number, we.l1_transaction_hash},
        order_by: [desc: we.msg_id],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end
end
