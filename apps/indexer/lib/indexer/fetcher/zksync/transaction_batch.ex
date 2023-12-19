defmodule Indexer.Fetcher.ZkSync.TransactionBatch do
  @moduledoc """
  Fills zkevm_transaction_batches DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import EthereumJSONRPC, only: [integer_to_quantity: 1, json_rpc: 2, quantity_to_integer: 1]

  alias Explorer.Chain
  # alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.ZkSync.Reader

  @zero_hash "0000000000000000000000000000000000000000000000000000000000000000"
  @zero_hash_binary <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

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
    Logger.metadata(fetcher: :zksync_transaction_batches)

    config = Application.get_all_env(:indexer)[Indexer.Fetcher.ZkSync.TransactionBatch]
    chunk_size = config[:chunk_size]
    recheck_interval = config[:recheck_interval]
    batches_max_range = config[:batches_max_range]

    Process.send(self(), :init, [])

    {:ok,
     %{
       chunk_size: chunk_size,
       batches_max_range: batches_max_range,
       json_rpc_named_arguments: args[:json_rpc_named_arguments],
       latest_handled_batch_number: 0,
       recheck_interval: recheck_interval
     }}
  end

  @impl GenServer
  def handle_info(
        :init,
        %{json_rpc_named_arguments: json_rpc_named_arguments} = state
      ) do

    latest_handled_batch_number =
      cond do
        latest_handled_batch_number = Reader.latest_available_batch_number() ->
          latest_handled_batch_number - 1

        true ->
          log_info("No batches found in DB")
          fetch_latest_sealed_batch_number(json_rpc_named_arguments) - 1
      end

    Process.send_after(self(), :continue, 2000)

    log_info("The latest unfinalized batch number #{latest_handled_batch_number}")

    {:noreply, %{
                 state
                 | latest_handled_batch_number: latest_handled_batch_number
                }}
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          chunk_size: chunk_size,
          batches_max_range: batches_max_range,
          json_rpc_named_arguments: json_rpc_named_arguments,
          latest_handled_batch_number: latest_handled_batch_number,
          recheck_interval: recheck_interval
        } = state
      ) do
    latest_sealed_batch_number = fetch_latest_sealed_batch_number(json_rpc_named_arguments)

    log_info("Checking for a new batch")

    {new_state, handle_duration} =
      if latest_handled_batch_number < latest_sealed_batch_number do
        start_batch_number = latest_handled_batch_number + 1
        end_batch_number = min(latest_sealed_batch_number, latest_handled_batch_number + batches_max_range)

        log_info("Handling the batch range #{start_batch_number}..#{end_batch_number}")

        {handle_duration, _} =
          :timer.tc(fn ->
            handle_batch_range(start_batch_number, end_batch_number, %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size})
          end)

        {
          %{
            state
            | latest_handled_batch_number: end_batch_number
          },
          div(handle_duration, 1000)
        }
      else
        {state, 0}
      end

    Process.send_after(self(), :continue, max(:timer.seconds(recheck_interval) - handle_duration, 0))

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp collect_batches_details(start_batch_number, end_batch_number, %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config) do
    start_batch_number..end_batch_number
    |> Enum.chunk_every(chunk_size)
    |> Enum.reduce(%{}, fn chunk, details ->
      chunk_start = List.first(chunk)
      chunk_end = List.last(chunk)

      log_details_batches_chunk_handling(chunk_start, chunk_end, start_batch_number, end_batch_number)
      requests =
        chunk_start..chunk_end
        |> Enum.map(fn batch_number ->
          EthereumJSONRPC.request(%{
            id: batch_number,
            method: "zks_getL1BatchDetails",
            params: [batch_number]
          })
        end)
      request_batches_details_by_rpc(requests, details, json_rpc_named_arguments)
    end)
  end

  defp get_block_ranges(batches, %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config) do
    keys = Map.keys(batches)
    batches_list_length = length(keys)
    # The main goal of this reduce to get blocks ranges for every batch
    # by combining zks_getL1BatchBlockRange requests in chunks
    {updated_batches, _} =
      keys
      |> Enum.chunk_every(chunk_size)
      |> Enum.reduce({batches, 0}, fn batches_chunk, {batches_with_blockranges, a} = _acc ->
        log_details_updates_chunk_handling(batches_chunk, a * chunk_size, batches_list_length)

        # Execute requests list and extend the batches details with blocks ranges
        batches_with_blockranges =
          batches_chunk
          |> Enum.reduce([], fn batch_number, requests ->
            batch = Map.get(batches, batch_number)
            # Prepare requests list to get blocks ranges
            case is_nil(batch.start_block) or is_nil(batch.end_block) do
              true ->
                [ EthereumJSONRPC.request(%{
                  id: batch_number,
                  method: "zks_getL1BatchBlockRange",
                  params: [batch_number]
                }) | requests ]
              false ->
                requests
            end
          end)
          |> request_block_ranges_by_rpc(batches_with_blockranges, json_rpc_named_arguments)

        {batches_with_blockranges, a + 1}
      end)

    updated_batches
  end

  defp get_l2_blocks_and_transactions(batches, %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config) do
    {blocks, chunked_requests, cur_chunk, cur_chunk_size} =
      Map.keys(batches)
      |> Enum.reduce({%{}, [], [], 0}, fn batch_number, {blocks, chunked_requests, cur_chunk, cur_chunk_size} = _acc ->
        batch = Map.get(batches, batch_number)
        log_info("The batch #{batch_number} contains blocks range #{batch.start_block}..#{batch.end_block}")
        batch.start_block..batch.end_block
        |> Enum.chunk_every(chunk_size)
        |> Enum.reduce({blocks, chunked_requests, cur_chunk, cur_chunk_size}, fn blocks_range, {blks, chnkd_rqsts, c_chunk, c_chunk_size} = _acc ->
          blocks_range
          |> Enum.reduce({blks, chnkd_rqsts, c_chunk, c_chunk_size}, fn block_number, {blks, chnkd_rqsts, c_chunk, c_chunk_size} = _acc ->
            blks = Map.put(blks, block_number, %{batch_number: batch_number, number: block_number})
            c_chunk = [ EthereumJSONRPC.request(%{
              id: block_number,
              method: "eth_getBlockByNumber",
              params: [integer_to_quantity(block_number), false]
            }) | c_chunk ]
            if c_chunk_size + 1 == chunk_size do
              {blks, [ c_chunk | chnkd_rqsts ], [], 0}
            else
              {blks, chnkd_rqsts, c_chunk, c_chunk_size + 1}
            end
          end)
        end)
      end)

    chunked_requests =
      if cur_chunk_size > 0 do
        [ cur_chunk| chunked_requests ]
      else
        chunked_requests
      end

    l2_txs_to_import =
      chunked_requests
      |> Enum.reduce([], fn requests, l2_txs ->
        request_transactions_by_rpc(requests, blocks, l2_txs, json_rpc_named_arguments)
      end)

    # Check that amount of received transactions for a batch is correct
    Map.keys(batches)
    |> Enum.each(fn batch_number ->
      batch = Map.get(batches, batch_number)
      txs_in_batch = batch.l1_tx_count + batch.l2_tx_count
      ^txs_in_batch = Enum.count(l2_txs_to_import, fn tx ->
        tx.batch_number == batch_number
      end)
    end)

    {Map.values(blocks), l2_txs_to_import}
  end

  defp handle_batch_range(start_batch_number, end_batch_number, config) do
    batches_to_import = collect_batches_details(start_batch_number, end_batch_number, config)
    log_info("Collected details for #{length(Map.keys(batches_to_import))} batches")

    batches_to_import = get_block_ranges(batches_to_import, config)

    { l2_blocks_to_import, l2_txs_to_import } =
      get_l2_blocks_and_transactions(batches_to_import, config)
    log_info("Linked #{length(l2_blocks_to_import)} L2 blocks and #{length(l2_txs_to_import)} L2 transactions")

    batches_list_to_import =
      Map.keys(batches_to_import)
      |> Enum.reduce([], fn batch_number, batches_list ->
        batch = Map.get(batches_to_import, batch_number)
        [ batch
          |> Map.drop([:commit_tx_hash, :commit_timestamp, :prove_tx_hash, :prove_timestamp, :executed_tx_hash, :executed_timestamp]) | batches_list ]
      end)

    {:ok, _} =
      Chain.import(%{
        zksync_transaction_batches: %{params: batches_list_to_import},
        timeout: :infinity
      })
  end

  defp fetch_latest_sealed_batch_number(json_rpc_named_arguments) do
    req = EthereumJSONRPC.request(%{id: 0, method: "zks_L1BatchNumber", params: []})

    error_message = &"Cannot call zks_L1BatchNumber. Error: #{inspect(&1)}"

    {:ok, resp} = repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, 3)

    quantity_to_integer(resp)
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

  defp from_ts_to_datetime(time_ts) do
    {_, unix_epoch_starts} = DateTime.from_unix(0)
    case is_nil(time_ts) or time_ts == 0 do
      true ->
        unix_epoch_starts
      false ->
        case  DateTime.from_unix(time_ts) do
          {:ok, datetime} ->
            datetime
          {:error, _} ->
            unix_epoch_starts
        end
    end
  end

  defp from_iso8601_to_datetime(time_string) do
    case is_nil(time_string) do
      true ->
        from_ts_to_datetime(0)
      false ->
        case DateTime.from_iso8601(time_string) do
          {:ok, datetime, _} ->
            datetime
          {:error, _} ->
            from_ts_to_datetime(0)
        end
    end
  end

  defp json_txid_to_hash(hash) do
    case hash do
      "0x" <> tx_hash -> tx_hash
      nil -> @zero_hash
    end
  end

  defp strhash_to_byteshash(hash) do
    hash
    |> json_txid_to_hash()
    |> Base.decode16!(case: :mixed)
  end

  defp transform_batch_details_to_map(json_response) do
    %{
      "number" => {:number, :ok},
      "timestamp" => {:timestamp, :ts_to_datetime},
      "l1TxCount" => {:l1_tx_count, :ok},
      "l2TxCount" => {:l2_tx_count, :ok},
      "rootHash" => {:root_hash, :str_to_byteshash},
      "commitTxHash" => {:commit_tx_hash, :str_to_byteshash},
      "committedAt" => {:commit_timestamp, :iso8601_to_datetime},
      "proveTxHash" => {:prove_tx_hash, :str_to_byteshash},
      "provenAt" => {:prove_timestamp, :iso8601_to_datetime} ,
      "executeTxHash" => {:executed_tx_hash, :str_to_byteshash},
      "executedAt" => {:executed_timestamp, :iso8601_to_datetime},
      "l1GasPrice" => {:l1_gas_price, :ok},
      "l2FairGasPrice" => {:l2_fair_gas_price, :ok}
      # :start_block added by request_block_ranges_by_rpc
      # :end_block added by request_block_ranges_by_rpc
    }
    |> Enum.reduce(%{start_block: nil, end_block: nil}, fn {key, {key_atom, transform_type}}, batch_details_map ->
      value_in_json_response = Map.get(json_response, key)
      Map.put(
        batch_details_map,
        key_atom,
        case transform_type do
          :iso8601_to_datetime -> from_iso8601_to_datetime(value_in_json_response)
          :ts_to_datetime -> from_ts_to_datetime(value_in_json_response)
          :str_to_txhash -> json_txid_to_hash(value_in_json_response)
          :str_to_byteshash -> strhash_to_byteshash(value_in_json_response)
          _ -> value_in_json_response
        end
      )
    end)
  end

  defp request_transactions_by_rpc([], _, l2_txs, _) do
    l2_txs
  end

  defp request_transactions_by_rpc(requests_list, l2_blocks, l2_txs, json_rpc_named_arguments) do
    error_message =
      &"Cannot call eth_getBlockByNumber. Error: #{inspect(&1)}"

    {:ok, responses} = repeated_call(&json_rpc/2, [requests_list, json_rpc_named_arguments], error_message, 3)

    responses
    |> Enum.reduce(l2_txs, fn resp, l2_txs ->
        batch_number =
          Map.get(l2_blocks, resp.id)
          |> Map.get(:batch_number)

        Map.get(resp.result, "transactions")
        |> Kernel.||([])
        |> Enum.reduce(l2_txs, fn l2_tx_hash, l2_txs ->
          [ %{
            batch_number: batch_number,
            hash: l2_tx_hash
          } | l2_txs ]
        end)
      end)
  end

  defp request_block_ranges_by_rpc([], batches_details, _) do
    batches_details
  end

  defp request_block_ranges_by_rpc(requests_list, batches_details, json_rpc_named_arguments) do
    error_message =
      &"Cannot call zks_getL1BatchBlockRange. Error: #{inspect(&1)}"

    {:ok, responses} = repeated_call(&json_rpc/2, [requests_list, json_rpc_named_arguments], error_message, 3)

    responses
    |> Enum.reduce(batches_details, fn resp, batches_details ->
        Map.update!(batches_details, resp.id, fn batch ->
          [start_block, end_block] = resp.result
          Map.merge(batch, %{start_block: quantity_to_integer(start_block), end_block: quantity_to_integer(end_block)})
        end)
      end)
  end

  defp request_batches_details_by_rpc([], batches_details, _) do
    batches_details
  end

  defp request_batches_details_by_rpc(requests_list, batches_details, json_rpc_named_arguments) do
    error_message =
      &"Cannot call zks_getL1BatchDetails. Error: #{inspect(&1)}"

    {:ok, responses} = repeated_call(&json_rpc/2, [requests_list, json_rpc_named_arguments], error_message, 3)

    responses
    |> Enum.reduce(
      batches_details,
      fn resp, batches_details ->
        Map.put(batches_details, resp.id, transform_batch_details_to_map(resp.result))
      end)
  end

  ###############################################################################
  ##### Logging related functions
  defp log_warning(msg) do
    Logger.warning(msg)
  end

  defp log_info(msg) do
    Logger.notice(msg)
  end

  defp log_details_updates_chunk_handling(chunk, current_progress, total) do
    chunk_length = length(chunk)
    progress =
      case chunk_length == total do
        true ->
          ""
        false ->
          percentage =
            Decimal.div(current_progress + chunk_length, total)
            |> Decimal.mult(100)
            |> Decimal.round(2)
            |> Decimal.to_string()
          " Progress: #{percentage}%"
      end
    log_info("Collecting block ranges for batches #{Enum.join(chunk, ", ")}.#{progress}")
  end

  defp log_details_batches_chunk_handling(chunk_start, chunk_end, start_block, end_block) do
    target_range =
      if chunk_start != start_block or chunk_end != end_block do
        percentage =
          (chunk_end - start_block + 1)
          |> Decimal.div(end_block - start_block + 1)
          |> Decimal.mult(100)
          |> Decimal.round(2)
          |> Decimal.to_string()

        " Target range: #{start_block}..#{end_block}. Progress: #{percentage}%"
      else
        ""
      end

    if chunk_start == chunk_end do
      log_info("Collecting details for batch ##{chunk_start}.#{target_range}")
    else
      log_info("Collecting details for batch range #{chunk_start}..#{chunk_end}.#{target_range}")
    end
  end

end
