defmodule Indexer.Fetcher.Optimism.Withdrawal do
  @moduledoc """
  Fills op_withdrawals DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [decode_data: 2, parse_integer: 1]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Log
  alias Explorer.Chain.Optimism.Withdrawal, as: OptimismWithdrawal
  alias Indexer.Fetcher.Optimism
  alias Indexer.Helper

  @fetcher_name :optimism_withdrawals
  @counter_type "optimism_withdrawals_fetcher_last_l2_block_hash"

  # 32-byte signature of the event MessagePassed(uint256 indexed nonce, address indexed sender, address indexed target, uint256 value, uint256 gasLimit, bytes data, bytes32 withdrawalHash)
  @message_passed_event "0x02a52367d10742d8032712c1bb8e0144ff1ec5ffda1ed7d70bb05a2744955054"

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
    {:ok, %{}, {:continue, args[:json_rpc_named_arguments]}}
  end

  @impl GenServer
  def handle_continue(json_rpc_named_arguments, state) do
    Logger.metadata(fetcher: @fetcher_name)

    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_l2_undefined, false} <- {:start_block_l2_undefined, is_nil(env[:start_block_l2])},
         {:message_passer_valid, true} <- {:message_passer_valid, Helper.address_correct?(env[:message_passer])},
         start_block_l2 = parse_integer(env[:start_block_l2]),
         false <- is_nil(start_block_l2),
         true <- start_block_l2 > 0,
         {last_l2_block_number, last_l2_transaction_hash, last_l2_transaction} <-
           get_last_l2_item(json_rpc_named_arguments),
         {safe_block, safe_block_is_latest} = Helper.get_safe_block(json_rpc_named_arguments),
         {:start_block_l2_valid, true} <-
           {:start_block_l2_valid,
            (start_block_l2 <= last_l2_block_number || last_l2_block_number == 0) && start_block_l2 <= safe_block},
         {:l2_transaction_not_found, false} <-
           {:l2_transaction_not_found, !is_nil(last_l2_transaction_hash) && is_nil(last_l2_transaction)} do
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         start_block: max(start_block_l2, last_l2_block_number),
         start_block_l2: start_block_l2,
         safe_block: safe_block,
         safe_block_is_latest: safe_block_is_latest,
         message_passer: env[:message_passer],
         json_rpc_named_arguments: json_rpc_named_arguments,
         eth_get_logs_range_size:
           Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism][:l2_eth_get_logs_range_size]
       }}
    else
      {:start_block_l2_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, state}

      {:message_passer_valid, false} ->
        Logger.error("L2ToL1MessagePasser contract address is invalid or not defined.")
        {:stop, :normal, state}

      {:start_block_l2_valid, false} ->
        Logger.error("Invalid L2 Start Block value. Please, check the value and op_withdrawals table.")
        {:stop, :normal, state}

      {:error, error_data} ->
        Logger.error("Cannot get last L2 transaction from RPC by its hash due to RPC error: #{inspect(error_data)}")

        {:stop, :normal, state}

      {:l2_transaction_not_found, true} ->
        Logger.error(
          "Cannot find last L2 transaction from RPC by its hash. Probably, there was a reorg on L2 chain. Please, check op_withdrawals table."
        )

        {:stop, :normal, state}

      _ ->
        Logger.error("Withdrawals L2 Start Block is invalid or zero.")
        {:stop, :normal, state}
    end
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          start_block_l2: start_block_l2,
          message_passer: message_passer,
          json_rpc_named_arguments: json_rpc_named_arguments,
          eth_get_logs_range_size: eth_get_logs_range_size
        } = state
      ) do
    fill_msg_nonce_gaps(start_block_l2, message_passer, json_rpc_named_arguments, eth_get_logs_range_size)
    Process.send(self(), :find_new_events, [])
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        :find_new_events,
        %{
          start_block: start_block,
          safe_block: safe_block,
          safe_block_is_latest: safe_block_is_latest,
          message_passer: message_passer,
          json_rpc_named_arguments: json_rpc_named_arguments,
          eth_get_logs_range_size: eth_get_logs_range_size
        } = state
      ) do
    # find and fill all events between start_block and "safe" block
    # the "safe" block can be "latest" (when safe_block_is_latest == true)
    fill_block_range(start_block, safe_block, message_passer, json_rpc_named_arguments, eth_get_logs_range_size)

    if not safe_block_is_latest do
      # find and fill all events between "safe" and "latest" block (excluding "safe")
      {:ok, latest_block} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments)
      fill_block_range(safe_block + 1, latest_block, message_passer, json_rpc_named_arguments, eth_get_logs_range_size)
    end

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  def remove(starting_block) do
    Repo.delete_all(from(w in OptimismWithdrawal, where: w.l2_block_number >= ^starting_block))
  end

  def event_to_withdrawal(second_topic, data, l2_transaction_hash, l2_block_number) do
    [_value, _gas_limit, _data, hash] = decode_data(data, [{:uint, 256}, {:uint, 256}, :bytes, {:bytes, 32}])

    msg_nonce =
      second_topic
      |> Helper.log_topic_to_string()
      |> quantity_to_integer()
      |> Decimal.new()

    %{
      msg_nonce: msg_nonce,
      hash: hash,
      l2_transaction_hash: l2_transaction_hash,
      l2_block_number: quantity_to_integer(l2_block_number)
    }
  end

  defp msg_nonce_gap_starts(nonce_max) do
    Repo.all(
      from(w in OptimismWithdrawal,
        select: w.l2_block_number,
        order_by: w.msg_nonce,
        where:
          fragment(
            "NOT EXISTS (SELECT msg_nonce FROM op_withdrawals WHERE msg_nonce = (? + 1)) AND msg_nonce != ?",
            w.msg_nonce,
            ^nonce_max
          )
      ),
      timeout: :infinity
    )
  end

  defp msg_nonce_gap_ends(nonce_min) do
    Repo.all(
      from(w in OptimismWithdrawal,
        select: w.l2_block_number,
        order_by: w.msg_nonce,
        where:
          fragment(
            "NOT EXISTS (SELECT msg_nonce FROM op_withdrawals WHERE msg_nonce = (? - 1)) AND msg_nonce != ?",
            w.msg_nonce,
            ^nonce_min
          )
      ),
      timeout: :infinity
    )
  end

  defp find_and_save_withdrawals(
         scan_db,
         message_passer,
         block_start,
         block_end,
         json_rpc_named_arguments
       ) do
    withdrawals =
      if scan_db do
        query =
          from(log in Log,
            select: {log.second_topic, log.data, log.transaction_hash, log.block_number},
            where:
              log.first_topic == ^@message_passed_event and log.address_hash == ^message_passer and
                log.block_number >= ^block_start and log.block_number <= ^block_end
          )

        query
        |> Repo.all(timeout: :infinity)
        |> Enum.map(fn {second_topic, data, l2_transaction_hash, l2_block_number} ->
          event_to_withdrawal(second_topic, data, l2_transaction_hash, l2_block_number)
        end)
      else
        {:ok, result} =
          Helper.get_logs(
            block_start,
            block_end,
            message_passer,
            [@message_passed_event],
            json_rpc_named_arguments,
            0,
            3
          )

        Enum.map(result, fn event ->
          event_to_withdrawal(
            Enum.at(event["topics"], 1),
            event["data"],
            event["transactionHash"],
            event["blockNumber"]
          )
        end)
      end

    {:ok, _} =
      Chain.import(%{
        optimism_withdrawals: %{params: withdrawals},
        timeout: :infinity
      })

    Enum.count(withdrawals)
  end

  defp fill_block_range(
         l2_block_start,
         l2_block_end,
         message_passer,
         json_rpc_named_arguments,
         eth_get_logs_range_size,
         scan_db
       ) do
    chunks_number =
      if scan_db do
        1
      else
        ceil((l2_block_end - l2_block_start + 1) / eth_get_logs_range_size)
      end

    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    Enum.reduce(chunk_range, 0, fn current_chunk, withdrawals_count_acc ->
      chunk_start = l2_block_start + eth_get_logs_range_size * current_chunk

      chunk_end =
        if scan_db do
          l2_block_end
        else
          min(chunk_start + eth_get_logs_range_size - 1, l2_block_end)
        end

      Helper.log_blocks_chunk_handling(chunk_start, chunk_end, l2_block_start, l2_block_end, nil, :L2)

      withdrawals_count =
        find_and_save_withdrawals(
          scan_db,
          message_passer,
          chunk_start,
          chunk_end,
          json_rpc_named_arguments
        )

      Helper.log_blocks_chunk_handling(
        chunk_start,
        chunk_end,
        l2_block_start,
        l2_block_end,
        "#{withdrawals_count} MessagePassed event(s)",
        :L2
      )

      withdrawals_count_acc + withdrawals_count
    end)
  end

  defp fill_block_range(start_block, end_block, message_passer, json_rpc_named_arguments, eth_get_logs_range_size) do
    if start_block <= end_block do
      fill_block_range(start_block, end_block, message_passer, json_rpc_named_arguments, eth_get_logs_range_size, true)
      fill_msg_nonce_gaps(start_block, message_passer, json_rpc_named_arguments, eth_get_logs_range_size, false)
      {last_l2_block_number, _, _} = get_last_l2_item()

      fill_block_range(
        max(start_block, last_l2_block_number),
        end_block,
        message_passer,
        json_rpc_named_arguments,
        eth_get_logs_range_size,
        false
      )

      Optimism.set_last_block_hash_by_number(end_block, @counter_type, json_rpc_named_arguments)
    end
  end

  defp fill_msg_nonce_gaps(
         start_block_l2,
         message_passer,
         json_rpc_named_arguments,
         eth_get_logs_range_size,
         scan_db \\ true
       ) do
    nonce_min = Repo.aggregate(OptimismWithdrawal, :min, :msg_nonce)
    nonce_max = Repo.aggregate(OptimismWithdrawal, :max, :msg_nonce)

    with true <- !is_nil(nonce_min) and !is_nil(nonce_max),
         starts = msg_nonce_gap_starts(nonce_max),
         ends = msg_nonce_gap_ends(nonce_min),
         min_block_l2 = l2_block_number_by_msg_nonce(nonce_min),
         {new_starts, new_ends} =
           if(start_block_l2 < min_block_l2,
             do: {[start_block_l2 | starts], [min_block_l2 | ends]},
             else: {starts, ends}
           ),
         true <- Enum.count(new_starts) == Enum.count(new_ends) do
      new_starts
      |> Enum.zip(new_ends)
      |> Enum.each(fn {l2_block_start, l2_block_end} ->
        withdrawals_count =
          fill_block_range(
            l2_block_start,
            l2_block_end,
            message_passer,
            json_rpc_named_arguments,
            eth_get_logs_range_size,
            scan_db
          )

        if withdrawals_count > 0 do
          log_fill_msg_nonce_gaps(scan_db, l2_block_start, l2_block_end, withdrawals_count)
        end
      end)

      if scan_db do
        fill_msg_nonce_gaps(start_block_l2, message_passer, json_rpc_named_arguments, eth_get_logs_range_size, false)
      end
    end
  end

  # Determines the last saved L2 block number, the last saved transaction hash, and the transaction info for withdrawals.
  #
  # Utilized to start fetching from a correct block number after reorg has occurred.
  #
  # ## Parameters
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #                               Used to get transaction info by its hash from the RPC node.
  #                               Can be `nil` if the transaction info is not needed.
  #
  # ## Returns
  # - A tuple `{last_block_number, last_transaction_hash, last_transaction}` where
  #   `last_block_number` is the last block number found in the corresponding table (0 if not found),
  #   `last_transaction_hash` is the last transaction hash found in the corresponding table (nil if not found),
  #   `last_transaction` is the transaction info got from the RPC (nil if not found or not needed).
  # - A tuple `{:error, message}` in case the `eth_getTransactionByHash` RPC request failed.
  @spec get_last_l2_item(EthereumJSONRPC.json_rpc_named_arguments() | nil) ::
          {non_neg_integer(), binary() | nil, map() | nil} | {:error, any()}
  defp get_last_l2_item(json_rpc_named_arguments \\ nil) do
    Optimism.get_last_item(
      :L2,
      &OptimismWithdrawal.last_withdrawal_l2_block_number_query/0,
      &OptimismWithdrawal.remove_withdrawals_query/1,
      json_rpc_named_arguments,
      @counter_type
    )
  end

  defp log_fill_msg_nonce_gaps(scan_db, l2_block_start, l2_block_end, withdrawals_count) do
    find_place = if scan_db, do: "in DB", else: "through RPC"

    Logger.info(
      "Filled gaps between L2 blocks #{l2_block_start} and #{l2_block_end}. #{withdrawals_count} event(s) were found #{find_place} and written to op_withdrawals table."
    )
  end

  defp l2_block_number_by_msg_nonce(nonce) do
    Repo.one(from(w in OptimismWithdrawal, select: w.l2_block_number, where: w.msg_nonce == ^nonce))
  end
end
