defmodule Indexer.Fetcher.PolygonSupernetDepositExecute do
  @moduledoc """
  Fills polygon_supernet_deposit_executes DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [parse_integer: 1]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Log, PolygonSupernetDepositExecute}
  alias Indexer.Fetcher.PolygonSupernet
  alias Indexer.Helper

  @fetcher_name :polygon_supernet_deposit_execute

  # 32-byte signature of the event StateSyncResult(uint256 indexed counter, bool indexed status, bytes message)
  @state_sync_result_event "0x31c652130602f3ce96ceaf8a4c2b8b49f049166c6fcf2eb31943a75ec7c936ae"

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
    Logger.metadata(fetcher: @fetcher_name)

    json_rpc_named_arguments = args[:json_rpc_named_arguments]
    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_l2_undefined, false} <- {:start_block_l2_undefined, is_nil(env[:start_block_l2])},
         {:state_receiver_valid, true} <- {:state_receiver_valid, Helper.is_address_correct?(env[:state_receiver])},
         start_block_l2 = parse_integer(env[:start_block_l2]),
         false <- is_nil(start_block_l2),
         true <- start_block_l2 > 0,
         {last_l2_block_number, last_l2_transaction_hash} <- get_last_l2_item(),
         {:ok, safe_block} = PolygonSupernet.get_block_number_by_tag("safe", json_rpc_named_arguments),
         {:start_block_l2_valid, true} <-
           {:start_block_l2_valid,
            (start_block_l2 <= last_l2_block_number || last_l2_block_number == 0) && start_block_l2 <= safe_block},
         {:ok, last_l2_tx} <-
           PolygonSupernet.get_transaction_by_hash(last_l2_transaction_hash, json_rpc_named_arguments),
         {:l2_tx_not_found, false} <- {:l2_tx_not_found, !is_nil(last_l2_transaction_hash) && is_nil(last_l2_tx)} do
      Process.send(self(), :continue, [])

      {:ok,
       %{
         start_block: max(start_block_l2, last_l2_block_number),
         start_block_l2: start_block_l2,
         safe_block: safe_block,
         state_receiver: env[:state_receiver],
         json_rpc_named_arguments: json_rpc_named_arguments
       }}
    else
      {:start_block_l2_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        :ignore

      {:state_receiver_valid, false} ->
        Logger.error("StateReceiver contract address is invalid or not defined.")
        :ignore

      {:start_block_l2_valid, false} ->
        Logger.error(
          "Invalid L2 Start Block value. Please, check the value and polygon_supernet_deposit_executes table."
        )

        :ignore

      {:error, error_data} ->
        Logger.error("Cannot get last L2 transaction from RPC by its hash due to RPC error: #{inspect(error_data)}")

        :ignore

      {:l2_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L2 transaction from RPC by its hash. Probably, there was a reorg on L2 chain. Please, check polygon_supernet_deposit_executes table."
        )

        :ignore

      _ ->
        Logger.error("Deposit Executes L2 Start Block is invalid or zero.")
        :ignore
    end
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          start_block_l2: start_block_l2,
          state_receiver: state_receiver,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    fill_msg_id_gaps(start_block_l2, state_receiver, json_rpc_named_arguments)
    Process.send(self(), :find_new_events, [])
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        :find_new_events,
        %{
          start_block: start_block,
          safe_block: safe_block,
          state_receiver: state_receiver,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    # find and fill all events between start_block and "safe" block
    fill_block_range(start_block, safe_block, state_receiver, json_rpc_named_arguments)

    # find and fill all events between "safe" and "latest" block (excluding "safe")
    {:ok, latest_block} = PolygonSupernet.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)
    fill_block_range(safe_block + 1, latest_block, state_receiver, json_rpc_named_arguments)

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  def remove(starting_block) do
    Repo.delete_all(from(de in PolygonSupernetDepositExecute, where: de.l2_block_number >= ^starting_block))
  end

  def event_to_deposit_execute(second_topic, third_topic, l2_transaction_hash, l2_block_number) do
    %{
      msg_id: quantity_to_integer(second_topic),
      l2_transaction_hash: l2_transaction_hash,
      l2_block_number: quantity_to_integer(l2_block_number),
      success: quantity_to_integer(third_topic) != 0
    }
  end

  defp msg_id_gap_starts(id_max) do
    Repo.all(
      from(de in PolygonSupernetDepositExecute,
        select: de.l2_block_number,
        order_by: de.msg_id,
        where:
          fragment(
            "NOT EXISTS (SELECT msg_id FROM polygon_supernet_deposit_executes WHERE msg_id = (? + 1)) AND msg_id != ?",
            de.msg_id,
            ^id_max
          )
      )
    )
  end

  defp msg_id_gap_ends(id_min) do
    Repo.all(
      from(de in PolygonSupernetDepositExecute,
        select: de.l2_block_number,
        order_by: de.msg_id,
        where:
          fragment(
            "NOT EXISTS (SELECT msg_id FROM polygon_supernet_deposit_executes WHERE msg_id = (? - 1)) AND msg_id != ?",
            de.msg_id,
            ^id_min
          )
      )
    )
  end

  defp find_and_save_deposit_executes(
         scan_db,
         state_receiver,
         block_start,
         block_end,
         json_rpc_named_arguments
       ) do
    executes =
      if scan_db do
        query =
          from(log in Log,
            select: {log.second_topic, log.third_topic, log.transaction_hash, log.block_number},
            where:
              log.first_topic == @state_sync_result_event and log.address_hash == ^state_receiver and
                log.block_number >= ^block_start and log.block_number <= ^block_end
          )

        query
        |> Repo.all(timeout: :infinity)
        |> Enum.map(fn {second_topic, third_topic, l2_transaction_hash, l2_block_number} ->
          event_to_deposit_execute(second_topic, third_topic, l2_transaction_hash, l2_block_number)
        end)
      else
        {:ok, result} =
          PolygonSupernet.get_logs(
            block_start,
            block_end,
            state_receiver,
            @state_sync_result_event,
            json_rpc_named_arguments,
            100_000_000
          )

        Enum.map(result, fn event ->
          event_to_deposit_execute(
            Enum.at(event["topics"], 1),
            Enum.at(event["topics"], 2),
            event["transactionHash"],
            event["blockNumber"]
          )
        end)
      end

    {:ok, _} =
      Chain.import(%{
        polygon_supernet_deposit_executes: %{params: executes},
        timeout: :infinity
      })

    Enum.count(executes)
  end

  defp fill_block_range(l2_block_start, l2_block_end, state_receiver, json_rpc_named_arguments, scan_db) do
    chunks_number =
      if scan_db do
        1
      else
        ceil((l2_block_end - l2_block_start + 1) / PolygonSupernet.get_logs_range_size())
      end

    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    Enum.reduce(chunk_range, 0, fn current_chunk, deposit_executes_count_acc ->
      chunk_start = l2_block_start + PolygonSupernet.get_logs_range_size() * current_chunk

      chunk_end =
        if scan_db do
          l2_block_end
        else
          min(chunk_start + PolygonSupernet.get_logs_range_size() - 1, l2_block_end)
        end

      PolygonSupernet.log_blocks_chunk_handling(chunk_start, chunk_end, l2_block_start, l2_block_end, nil, "L2")

      deposit_executes_count =
        find_and_save_deposit_executes(
          scan_db,
          state_receiver,
          chunk_start,
          chunk_end,
          json_rpc_named_arguments
        )

      PolygonSupernet.log_blocks_chunk_handling(
        chunk_start,
        chunk_end,
        l2_block_start,
        l2_block_end,
        "#{deposit_executes_count} StateSyncResult event(s)",
        "L2"
      )

      deposit_executes_count_acc + deposit_executes_count
    end)
  end

  defp fill_block_range(start_block, end_block, state_receiver, json_rpc_named_arguments) do
    fill_block_range(start_block, end_block, state_receiver, json_rpc_named_arguments, true)
    fill_msg_id_gaps(start_block, state_receiver, json_rpc_named_arguments, false)
    {last_l2_block_number, _} = get_last_l2_item()
    fill_block_range(max(start_block, last_l2_block_number), end_block, state_receiver, json_rpc_named_arguments, false)
  end

  defp fill_msg_id_gaps(start_block_l2, state_receiver, json_rpc_named_arguments, scan_db \\ true) do
    id_min = Repo.aggregate(PolygonSupernetDepositExecute, :min, :msg_id)
    id_max = Repo.aggregate(PolygonSupernetDepositExecute, :max, :msg_id)

    with true <- !is_nil(id_min) and !is_nil(id_max),
         starts = msg_id_gap_starts(id_max),
         ends = msg_id_gap_ends(id_min),
         min_block_l2 = l2_block_number_by_msg_id(id_min),
         {new_starts, new_ends} =
           if(start_block_l2 < min_block_l2,
             do: {[start_block_l2 | starts], [min_block_l2 | ends]},
             else: {starts, ends}
           ),
         true <- Enum.count(new_starts) == Enum.count(new_ends) do
      new_starts
      |> Enum.zip(new_ends)
      |> Enum.each(fn {l2_block_start, l2_block_end} ->
        deposit_executes_count =
          fill_block_range(l2_block_start, l2_block_end, state_receiver, json_rpc_named_arguments, scan_db)

        if deposit_executes_count > 0 do
          log_fill_msg_id_gaps(scan_db, l2_block_start, l2_block_end, deposit_executes_count)
        end
      end)

      if scan_db do
        fill_msg_id_gaps(start_block_l2, state_receiver, json_rpc_named_arguments, false)
      end
    end
  end

  defp get_last_l2_item do
    query =
      from(de in PolygonSupernetDepositExecute,
        select: {de.l2_block_number, de.l2_transaction_hash},
        order_by: [desc: de.msg_id],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  defp log_fill_msg_id_gaps(scan_db, l2_block_start, l2_block_end, deposit_executes_count) do
    find_place = if scan_db, do: "in DB", else: "through RPC"

    Logger.info(
      "Filled gaps between L2 blocks #{l2_block_start} and #{l2_block_end}. #{deposit_executes_count} event(s) were found #{find_place} and written to polygon_supernet_deposit_executes table."
    )
  end

  defp l2_block_number_by_msg_id(id) do
    Repo.one(from(de in PolygonSupernetDepositExecute, select: de.l2_block_number, where: de.msg_id == ^id))
  end
end
