defmodule Indexer.Fetcher.PolygonEdge do
  @moduledoc """
  Contains common functions for PolygonEdge.* fetchers.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC,
    only: [fetch_block_number_by_tag: 2, json_rpc: 2, integer_to_quantity: 1, quantity_to_integer: 1, request: 1]

  import Explorer.Helper, only: [parse_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias Explorer.Chain.Events.Publisher
  alias Explorer.{Chain, Repo}
  alias Indexer.{BoundQueue, Helper}
  alias Indexer.Fetcher.PolygonEdge.{Deposit, DepositExecute, Withdrawal, WithdrawalExit}

  @fetcher_name :polygon_edge
  @block_check_interval_range_size 100

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

    modules_using_reorg_monitor = [Deposit, WithdrawalExit]

    reorg_monitor_not_needed =
      modules_using_reorg_monitor
      |> Enum.all?(fn module ->
        is_nil(Application.get_all_env(:indexer)[module][:start_block_l1])
      end)

    if reorg_monitor_not_needed do
      :ignore
    else
      polygon_edge_l1_rpc = Application.get_all_env(:indexer)[Indexer.Fetcher.PolygonEdge][:polygon_edge_l1_rpc]

      json_rpc_named_arguments = json_rpc_named_arguments(polygon_edge_l1_rpc)

      {:ok, block_check_interval, _} = get_block_check_interval(json_rpc_named_arguments)

      Process.send(self(), :reorg_monitor, [])

      {:ok,
       %{block_check_interval: block_check_interval, json_rpc_named_arguments: json_rpc_named_arguments, prev_latest: 0}}
    end
  end

  @spec init_l1(
          Explorer.Chain.PolygonEdge.Deposit | Explorer.Chain.PolygonEdge.WithdrawalExit,
          list(),
          pid(),
          binary(),
          binary(),
          binary(),
          binary()
        ) :: {:ok, map()} | :ignore
  def init_l1(table, env, pid, contract_address, contract_name, table_name, entity_name)
      when table in [Explorer.Chain.PolygonEdge.Deposit, Explorer.Chain.PolygonEdge.WithdrawalExit] do
    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         {:reorg_monitor_started, true} <-
           {:reorg_monitor_started, !is_nil(Process.whereis(Indexer.Fetcher.PolygonEdge))},
         polygon_edge_l1_rpc = Application.get_all_env(:indexer)[Indexer.Fetcher.PolygonEdge][:polygon_edge_l1_rpc],
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(polygon_edge_l1_rpc)},
         {:contract_is_valid, true} <- {:contract_is_valid, Helper.is_address_correct?(contract_address)},
         start_block_l1 = parse_integer(env[:start_block_l1]),
         false <- is_nil(start_block_l1),
         true <- start_block_l1 > 0,
         {last_l1_block_number, last_l1_transaction_hash} <- get_last_l1_item(table),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
         json_rpc_named_arguments = json_rpc_named_arguments(polygon_edge_l1_rpc),
         {:ok, last_l1_tx} <-
           get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments, 100_000_000),
         {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_tx)},
         {:ok, block_check_interval, last_safe_block} <-
           get_block_check_interval(json_rpc_named_arguments) do
      start_block = max(start_block_l1, last_l1_block_number)

      Process.send(pid, :continue, [])

      {:ok,
       %{
         contract_address: contract_address,
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
        Logger.error("Cannot start this process as reorg monitor in Indexer.Fetcher.PolygonEdge is not started.")
        :ignore

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        :ignore

      {:contract_is_valid, false} ->
        Logger.error("#{contract_name} contract address is invalid or not defined.")
        :ignore

      {:start_block_l1_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and #{table_name} table.")

        :ignore

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L1 transaction from RPC by its hash, last safe block, or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )

        :ignore

      {:l1_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check #{table_name} table."
        )

        :ignore

      _ ->
        Logger.error("#{entity_name} L1 Start Block is invalid or zero.")
        :ignore
    end
  end

  @spec init_l2(
          Explorer.Chain.PolygonEdge.DepositExecute | Explorer.Chain.PolygonEdge.Withdrawal,
          list(),
          pid(),
          binary(),
          binary(),
          binary(),
          binary(),
          list()
        ) :: {:ok, map()} | :ignore
  def init_l2(table, env, pid, contract_address, contract_name, table_name, entity_name, json_rpc_named_arguments)
      when table in [Explorer.Chain.PolygonEdge.DepositExecute, Explorer.Chain.PolygonEdge.Withdrawal] do
    with {:start_block_l2_undefined, false} <- {:start_block_l2_undefined, is_nil(env[:start_block_l2])},
         {:contract_address_valid, true} <- {:contract_address_valid, Helper.is_address_correct?(contract_address)},
         start_block_l2 = parse_integer(env[:start_block_l2]),
         false <- is_nil(start_block_l2),
         true <- start_block_l2 > 0,
         {last_l2_block_number, last_l2_transaction_hash} <- get_last_l2_item(table),
         {safe_block, safe_block_is_latest} = get_safe_block(json_rpc_named_arguments),
         {:start_block_l2_valid, true} <-
           {:start_block_l2_valid,
            (start_block_l2 <= last_l2_block_number || last_l2_block_number == 0) && start_block_l2 <= safe_block},
         {:ok, last_l2_tx} <- get_transaction_by_hash(last_l2_transaction_hash, json_rpc_named_arguments, 100_000_000),
         {:l2_tx_not_found, false} <- {:l2_tx_not_found, !is_nil(last_l2_transaction_hash) && is_nil(last_l2_tx)} do
      Process.send(pid, :continue, [])

      {:ok,
       %{
         start_block: max(start_block_l2, last_l2_block_number),
         start_block_l2: start_block_l2,
         safe_block: safe_block,
         safe_block_is_latest: safe_block_is_latest,
         contract_address: contract_address,
         json_rpc_named_arguments: json_rpc_named_arguments
       }}
    else
      {:start_block_l2_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        :ignore

      {:contract_address_valid, false} ->
        Logger.error("#{contract_name} contract address is invalid or not defined.")
        :ignore

      {:start_block_l2_valid, false} ->
        Logger.error("Invalid L2 Start Block value. Please, check the value and #{table_name} table.")

        :ignore

      {:error, error_data} ->
        Logger.error("Cannot get last L2 transaction from RPC by its hash due to RPC error: #{inspect(error_data)}")

        :ignore

      {:l2_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L2 transaction from RPC by its hash. Probably, there was a reorg on L2 chain. Please, check #{table_name} table."
        )

        :ignore

      _ ->
        Logger.error("#{entity_name} L2 Start Block is invalid or zero.")
        :ignore
    end
  end

  @impl GenServer
  def handle_info(
        :reorg_monitor,
        %{
          block_check_interval: block_check_interval,
          json_rpc_named_arguments: json_rpc_named_arguments,
          prev_latest: prev_latest
        } = state
      ) do
    {:ok, latest} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

    if latest < prev_latest do
      Logger.warning("Reorg detected: previous latest block ##{prev_latest}, current latest block ##{latest}.")

      Publisher.broadcast([{:polygon_edge_reorg_block, latest}], :realtime)
    end

    Process.send_after(self(), :reorg_monitor, block_check_interval)

    {:noreply, %{state | prev_latest: latest}}
  end

  @spec handle_continue(map(), binary(), Deposit | WithdrawalExit, atom()) :: {:noreply, map()}
  def handle_continue(
        %{
          contract_address: contract_address,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state,
        event_signature,
        calling_module,
        fetcher_name
      )
      when calling_module in [Deposit, WithdrawalExit] do
    time_before = Timex.now()

    eth_get_logs_range_size =
      Application.get_all_env(:indexer)[Indexer.Fetcher.PolygonEdge][:polygon_edge_eth_get_logs_range_size]

    chunks_number = ceil((end_block - start_block + 1) / eth_get_logs_range_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    last_written_block =
      chunk_range
      |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
        chunk_start = start_block + eth_get_logs_range_size * current_chunk
        chunk_end = min(chunk_start + eth_get_logs_range_size - 1, end_block)

        if chunk_end >= chunk_start do
          log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, "L1")

          {:ok, result} =
            get_logs(
              chunk_start,
              chunk_end,
              contract_address,
              event_signature,
              json_rpc_named_arguments,
              100_000_000
            )

          {events, event_name} =
            result
            |> calling_module.prepare_events(json_rpc_named_arguments)
            |> import_events(calling_module)

          log_blocks_chunk_handling(
            chunk_start,
            chunk_end,
            start_block,
            end_block,
            "#{Enum.count(events)} #{event_name} event(s)",
            "L1"
          )
        end

        reorg_block = reorg_block_pop(fetcher_name)

        if !is_nil(reorg_block) && reorg_block > 0 do
          reorg_handle(reorg_block, calling_module)
          {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
        else
          {:cont, chunk_end}
        end
      end)

    new_start_block = last_written_block + 1
    {:ok, new_end_block} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

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

  @spec fill_block_range(integer(), integer(), DepositExecute | Withdrawal, binary(), list(), boolean()) :: integer()
  def fill_block_range(
        l2_block_start,
        l2_block_end,
        calling_module,
        contract_address,
        json_rpc_named_arguments,
        scan_db
      )
      when calling_module in [
             DepositExecute,
             Withdrawal
           ] do
    eth_get_logs_range_size =
      Application.get_all_env(:indexer)[Indexer.Fetcher.PolygonEdge][:polygon_edge_eth_get_logs_range_size]

    chunks_number =
      if scan_db do
        1
      else
        ceil((l2_block_end - l2_block_start + 1) / eth_get_logs_range_size)
      end

    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    Enum.reduce(chunk_range, 0, fn current_chunk, count_acc ->
      chunk_start = l2_block_start + eth_get_logs_range_size * current_chunk

      chunk_end =
        if scan_db do
          l2_block_end
        else
          min(chunk_start + eth_get_logs_range_size - 1, l2_block_end)
        end

      log_blocks_chunk_handling(chunk_start, chunk_end, l2_block_start, l2_block_end, nil, "L2")

      count =
        calling_module.find_and_save_entities(
          scan_db,
          contract_address,
          chunk_start,
          chunk_end,
          json_rpc_named_arguments
        )

      event_name =
        if calling_module == Indexer.Fetcher.PolygonEdge.DepositExecute do
          "StateSyncResult"
        else
          "L2StateSynced"
        end

      log_blocks_chunk_handling(
        chunk_start,
        chunk_end,
        l2_block_start,
        l2_block_end,
        "#{count} #{event_name} event(s)",
        "L2"
      )

      count_acc + count
    end)
  end

  @spec fill_block_range(integer(), integer(), {module(), module()}, binary(), list()) :: integer()
  def fill_block_range(start_block, end_block, {module, table}, contract_address, json_rpc_named_arguments) do
    fill_block_range(start_block, end_block, module, contract_address, json_rpc_named_arguments, true)

    fill_msg_id_gaps(
      start_block,
      table,
      module,
      contract_address,
      json_rpc_named_arguments,
      false
    )

    {last_l2_block_number, _} = get_last_l2_item(table)

    fill_block_range(
      max(start_block, last_l2_block_number),
      end_block,
      module,
      contract_address,
      json_rpc_named_arguments,
      false
    )
  end

  @spec fill_msg_id_gaps(integer(), module(), module(), binary(), list(), boolean()) :: no_return()
  def fill_msg_id_gaps(
        start_block_l2,
        table,
        calling_module,
        contract_address,
        json_rpc_named_arguments,
        scan_db \\ true
      ) do
    id_min = Repo.aggregate(table, :min, :msg_id)
    id_max = Repo.aggregate(table, :max, :msg_id)

    with true <- !is_nil(id_min) and !is_nil(id_max),
         starts = msg_id_gap_starts(id_max, table),
         ends = msg_id_gap_ends(id_min, table),
         min_block_l2 = l2_block_number_by_msg_id(id_min, table),
         {new_starts, new_ends} =
           if(start_block_l2 < min_block_l2,
             do: {[start_block_l2 | starts], [min_block_l2 | ends]},
             else: {starts, ends}
           ),
         true <- Enum.count(new_starts) == Enum.count(new_ends) do
      ranges = Enum.zip(new_starts, new_ends)

      invalid_range_exists = Enum.any?(ranges, fn {l2_block_start, l2_block_end} -> l2_block_start > l2_block_end end)

      ranges_final =
        with {:ranges_are_invalid, true} <- {:ranges_are_invalid, invalid_range_exists},
             {max_block_l2, _} = get_last_l2_item(table),
             {:start_block_l2_is_min, true} <- {:start_block_l2_is_min, start_block_l2 <= max_block_l2} do
          [{start_block_l2, max_block_l2}]
        else
          {:ranges_are_invalid, false} -> ranges
          {:start_block_l2_is_min, false} -> []
        end

      ranges_final
      |> Enum.each(fn {l2_block_start, l2_block_end} ->
        count =
          fill_block_range(
            l2_block_start,
            l2_block_end,
            calling_module,
            contract_address,
            json_rpc_named_arguments,
            scan_db
          )

        if count > 0 do
          log_fill_msg_id_gaps(scan_db, l2_block_start, l2_block_end, table, count)
        end
      end)

      if scan_db do
        fill_msg_id_gaps(start_block_l2, table, calling_module, contract_address, json_rpc_named_arguments, false)
      end
    end
  end

  defp log_fill_msg_id_gaps(scan_db, l2_block_start, l2_block_end, table, count) do
    find_place = if scan_db, do: "in DB", else: "through RPC"
    table_name = table.__schema__(:source)

    Logger.info(
      "Filled gaps between L2 blocks #{l2_block_start} and #{l2_block_end}. #{count} event(s) were found #{find_place} and written to #{table_name} table."
    )
  end

  defp msg_id_gap_starts(id_max, table)
       when table in [Explorer.Chain.PolygonEdge.DepositExecute, Explorer.Chain.PolygonEdge.Withdrawal] do
    query =
      if table == Explorer.Chain.PolygonEdge.DepositExecute do
        from(item in table,
          select: item.l2_block_number,
          order_by: item.msg_id,
          where:
            fragment(
              "NOT EXISTS (SELECT msg_id FROM polygon_edge_deposit_executes WHERE msg_id = (? + 1)) AND msg_id != ?",
              item.msg_id,
              ^id_max
            )
        )
      else
        from(item in table,
          select: item.l2_block_number,
          order_by: item.msg_id,
          where:
            fragment(
              "NOT EXISTS (SELECT msg_id FROM polygon_edge_withdrawals WHERE msg_id = (? + 1)) AND msg_id != ?",
              item.msg_id,
              ^id_max
            )
        )
      end

    Repo.all(query)
  end

  defp msg_id_gap_ends(id_min, table)
       when table in [Explorer.Chain.PolygonEdge.DepositExecute, Explorer.Chain.PolygonEdge.Withdrawal] do
    query =
      if table == Explorer.Chain.PolygonEdge.DepositExecute do
        from(item in table,
          select: item.l2_block_number,
          order_by: item.msg_id,
          where:
            fragment(
              "NOT EXISTS (SELECT msg_id FROM polygon_edge_deposit_executes WHERE msg_id = (? - 1)) AND msg_id != ?",
              item.msg_id,
              ^id_min
            )
        )
      else
        from(item in table,
          select: item.l2_block_number,
          order_by: item.msg_id,
          where:
            fragment(
              "NOT EXISTS (SELECT msg_id FROM polygon_edge_withdrawals WHERE msg_id = (? - 1)) AND msg_id != ?",
              item.msg_id,
              ^id_min
            )
        )
      end

    Repo.all(query)
  end

  defp get_block_check_interval(json_rpc_named_arguments) do
    {last_safe_block, _} = get_safe_block(json_rpc_named_arguments)

    first_block = max(last_safe_block - @block_check_interval_range_size, 1)

    with {:ok, first_block_timestamp} <-
           get_block_timestamp_by_number(first_block, json_rpc_named_arguments, 100_000_000),
         {:ok, last_safe_block_timestamp} <-
           get_block_timestamp_by_number(last_safe_block, json_rpc_named_arguments, 100_000_000) do
      block_check_interval =
        ceil((last_safe_block_timestamp - first_block_timestamp) / (last_safe_block - first_block) * 1000 / 2)

      Logger.info("Block check interval is calculated as #{block_check_interval} ms.")
      {:ok, block_check_interval, last_safe_block}
    else
      {:error, error} ->
        {:error, "Failed to calculate block check interval due to #{inspect(error)}"}
    end
  end

  @spec get_block_number_by_tag(binary(), list(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_block_number_by_tag(tag, json_rpc_named_arguments, retries \\ 3) do
    error_message = &"Cannot fetch #{tag} block number. Error: #{inspect(&1)}"
    repeated_call(&fetch_block_number_by_tag/2, [tag, json_rpc_named_arguments], error_message, retries)
  end

  defp get_block_timestamp_by_number_inner(number, json_rpc_named_arguments) do
    result =
      %{id: 0, number: number}
      |> ByNumber.request(false)
      |> json_rpc(json_rpc_named_arguments)

    with {:ok, block} <- result,
         false <- is_nil(block),
         timestamp <- Map.get(block, "timestamp"),
         false <- is_nil(timestamp) do
      {:ok, quantity_to_integer(timestamp)}
    else
      {:error, message} ->
        {:error, message}

      true ->
        {:error, "RPC returned nil."}
    end
  end

  defp get_block_timestamp_by_number(number, json_rpc_named_arguments, retries) do
    func = &get_block_timestamp_by_number_inner/2
    args = [number, json_rpc_named_arguments]
    error_message = &"Cannot fetch block ##{number} or its timestamp. Error: #{inspect(&1)}"
    repeated_call(func, args, error_message, retries)
  end

  defp get_safe_block(json_rpc_named_arguments) do
    case get_block_number_by_tag("safe", json_rpc_named_arguments) do
      {:ok, safe_block} ->
        {safe_block, false}

      {:error, :not_found} ->
        {:ok, latest_block} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)
        {latest_block, true}
    end
  end

  @spec get_logs(
          non_neg_integer() | binary(),
          non_neg_integer() | binary(),
          binary(),
          binary(),
          list(),
          non_neg_integer()
        ) :: {:ok, list()} | {:error, term()}
  def get_logs(from_block, to_block, address, topic0, json_rpc_named_arguments, retries) do
    processed_from_block = if is_integer(from_block), do: integer_to_quantity(from_block), else: from_block
    processed_to_block = if is_integer(to_block), do: integer_to_quantity(to_block), else: to_block

    req =
      request(%{
        id: 0,
        method: "eth_getLogs",
        params: [
          %{
            :fromBlock => processed_from_block,
            :toBlock => processed_to_block,
            :address => address,
            :topics => [topic0]
          }
        ]
      })

    error_message = &"Cannot fetch logs for the block range #{from_block}..#{to_block}. Error: #{inspect(&1)}"

    repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  defp get_transaction_by_hash(hash, _json_rpc_named_arguments, _retries_left) when is_nil(hash), do: {:ok, nil}

  defp get_transaction_by_hash(hash, json_rpc_named_arguments, retries) do
    req =
      request(%{
        id: 0,
        method: "eth_getTransactionByHash",
        params: [hash]
      })

    error_message = &"eth_getTransactionByHash failed. Error: #{inspect(&1)}"

    repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  defp get_last_l1_item(table) do
    query =
      from(item in table,
        select: {item.l1_block_number, item.l1_transaction_hash},
        order_by: [desc: item.msg_id],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  @spec get_last_l2_item(module()) :: {non_neg_integer(), binary() | nil}
  def get_last_l2_item(table) do
    query =
      from(item in table,
        select: {item.l2_block_number, item.l2_transaction_hash},
        order_by: [desc: item.msg_id],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  defp json_rpc_named_arguments(polygon_edge_l1_rpc) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        url: polygon_edge_l1_rpc,
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ]
    ]
  end

  defp l2_block_number_by_msg_id(id, table) do
    Repo.one(from(item in table, select: item.l2_block_number, where: item.msg_id == ^id))
  end

  defp log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, items_count, layer) do
    is_start = is_nil(items_count)

    {type, found} =
      if is_start do
        {"Start", ""}
      else
        {"Finish", " Found #{items_count}."}
      end

    target_range =
      if chunk_start != start_block or chunk_end != end_block do
        progress =
          if is_start do
            ""
          else
            percentage =
              (chunk_end - start_block + 1)
              |> Decimal.div(end_block - start_block + 1)
              |> Decimal.mult(100)
              |> Decimal.round(2)
              |> Decimal.to_string()

            " Progress: #{percentage}%"
          end

        " Target range: #{start_block}..#{end_block}.#{progress}"
      else
        ""
      end

    if chunk_start == chunk_end do
      Logger.info("#{type} handling #{layer} block ##{chunk_start}.#{found}#{target_range}")
    else
      Logger.info("#{type} handling #{layer} block range #{chunk_start}..#{chunk_end}.#{found}#{target_range}")
    end
  end

  defp import_events(events, calling_module) do
    {import_data, event_name} =
      if calling_module == Deposit do
        {%{polygon_edge_deposits: %{params: events}, timeout: :infinity}, "StateSynced"}
      else
        {%{polygon_edge_withdrawal_exits: %{params: events}, timeout: :infinity}, "ExitProcessed"}
      end

    {:ok, _} = Chain.import(import_data)

    {events, event_name}
  end

  defp log_deleted_rows_count(reorg_block, count, table_name) do
    if count > 0 do
      Logger.warning(
        "As L1 reorg was detected, all rows with l1_block_number >= #{reorg_block} were removed from the #{table_name} table. Number of removed rows: #{count}."
      )
    end
  end

  defp repeated_call(func, args, error_message, retries_left) do
    case apply(func, args) do
      {:ok, _} = res ->
        res

      {:error, message} = err ->
        retries_left = retries_left - 1

        if retries_left <= 0 do
          Logger.error(error_message.(message))
          err
        else
          Logger.error("#{error_message.(message)} Retrying...")
          :timer.sleep(3000)
          repeated_call(func, args, error_message, retries_left)
        end
    end
  end

  @spec repeated_request(list(), any(), list(), non_neg_integer()) :: {:ok, any()} | {:error, atom()}
  def repeated_request(req, error_message, json_rpc_named_arguments, retries) do
    repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  defp reorg_block_pop(fetcher_name) do
    table_name = reorg_table_name(fetcher_name)

    case BoundQueue.pop_front(reorg_queue_get(table_name)) do
      {:ok, {block_number, updated_queue}} ->
        :ets.insert(table_name, {:queue, updated_queue})
        block_number

      {:error, :empty} ->
        nil
    end
  end

  @spec reorg_block_push(atom(), non_neg_integer()) :: no_return()
  def reorg_block_push(fetcher_name, block_number) do
    table_name = reorg_table_name(fetcher_name)
    {:ok, updated_queue} = BoundQueue.push_back(reorg_queue_get(table_name), block_number)
    :ets.insert(table_name, {:queue, updated_queue})
  end

  defp reorg_handle(reorg_block, calling_module) do
    {table, table_name} =
      if calling_module == Deposit do
        {Explorer.Chain.PolygonEdge.Deposit, "polygon_edge_deposits"}
      else
        {Explorer.Chain.PolygonEdge.WithdrawalExit, "polygon_edge_withdrawal_exits"}
      end

    {deleted_count, _} = Repo.delete_all(from(item in table, where: item.l1_block_number >= ^reorg_block))

    log_deleted_rows_count(reorg_block, deleted_count, table_name)
  end

  defp reorg_queue_get(table_name) do
    if :ets.whereis(table_name) == :undefined do
      :ets.new(table_name, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    with info when info != :undefined <- :ets.info(table_name),
         [{_, value}] <- :ets.lookup(table_name, :queue) do
      value
    else
      _ -> %BoundQueue{}
    end
  end

  defp reorg_table_name(fetcher_name) do
    :"#{fetcher_name}#{:_reorgs}"
  end
end
