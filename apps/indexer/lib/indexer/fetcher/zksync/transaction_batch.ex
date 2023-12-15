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

    Process.send(self(), :init, [])

    {:ok,
     %{
       chunk_size: chunk_size,
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
    latest_handled_batch_number = Reader.last_executed_batch_number()

    latest_handled_batch_number =
      if is_nil(latest_handled_batch_number) do
        log_info("No lastest executed batch found in DB")
        latest_handled_batch_number = Reader.oldest_available_batch_number()
        if is_nil(latest_handled_batch_number) do
          log_info("No batches found in DB")
          # fetch_latest_sealed_batch_number(json_rpc_named_arguments) - 1
          fetch_latest_sealed_batch_number(json_rpc_named_arguments) - 20
        else
          latest_handled_batch_number - 1
        end
      else
        latest_handled_batch_number
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
        end_batch_number = latest_sealed_batch_number

        log_info("Handling the batch range #{start_batch_number}..#{end_batch_number}")

        {handle_duration, latest_handled_batch_number} =
          :timer.tc(fn ->
            # handle_batch_range(start_batch_number, end_batch_number, %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size})
            handle_batch_range(start_batch_number, end_batch_number, %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: 50})
          end)

        {
          %{
            state
            | latest_handled_batch_number: latest_handled_batch_number
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

  defp extract_l1_tx_and_get_block_ranges(batches, %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config) do
    keys = Map.keys(batches)
    batches_list_length = length(keys)
    # The main goal of this reduce to get blocks ranges for every batch
    # by combining zks_getL1BatchBlockRange requests in chunks
    # But for optimization purposes the same loop is used to collect
    # batch changing L1 transactions. These two operations can be divided
    # in two separate reduces later to simplify sustainability
    {updated_batches, l1_txs, _} =
      keys
      |> Enum.chunk_every(chunk_size)
      |> Enum.reduce({batches, %{}, 0}, fn batches_chunk, {batches_with_blockranges, l1_txs, a} = _acc ->
        log_details_updates_chunk_handling(batches_chunk, a * chunk_size, batches_list_length)

        {requests, l1_txs} =
          batches_chunk
          |> Enum.reduce({[], l1_txs}, fn batch_number, {requests, l1_txs} = _acc ->
            batch = Map.get(batches, batch_number)
            # Prepare requests list to get blocks ranges
            requests =
              # Assumes that batches in DB already has the block range set
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

            # Collect L1 transactions changing batches status
            l1_txs =
              [%{hash: batch.commit_tx_hash, ts: batch.commit_timestamp},
               %{hash: batch.prove_tx_hash, ts: batch.prove_timestamp},
               %{hash: batch.executed_tx_hash, ts: batch.executed_timestamp}
              ]
              |> Enum.reduce(l1_txs, fn l1_tx, acc ->
                if l1_tx.hash != @zero_hash_binary do
                  Map.put(acc, l1_tx.hash, %{hash: l1_tx.hash, timestamp: l1_tx.ts})
                else
                  acc
                end
              end)

            {requests, l1_txs}
          end)

        # Execute requests list and extend the batches details with blocks ranges
        batches_with_blockranges =
          request_block_ranges_by_rpc(requests, batches_with_blockranges, json_rpc_named_arguments)

        {batches_with_blockranges, l1_txs, a + 1}
      end)

    # Get indices for l1 transactions previously handled
    l1_txs =
      Map.keys(l1_txs)
      |> Reader.lifecycle_transactions()
      |> Enum.reduce(l1_txs, fn {hash, id}, txs ->
        {_, txs} = Map.get_and_update!(txs, hash.bytes, fn l1_tx ->
          {l1_tx, Map.put(l1_tx, :id, id)}
        end)
        txs
      end)

    # Provide indices for new L1 transactions
    l1_tx_next_id = Reader.next_id()
    { l1_txs, _ } =
      Map.keys(l1_txs)
      |> Enum.reduce({l1_txs, l1_tx_next_id}, fn hash, {txs, next_id} = _acc ->
        tx = Map.get(txs, hash)
        id = Map.get(tx, :id)
        if is_nil(id) do
          {Map.put(txs, hash, Map.put(tx, :id, next_id)), next_id + 1}
        else
          {txs, next_id}
        end
      end)

    {updated_batches, l1_txs}
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

  defp is_transactions_of_batch_changed(batch_db, batch_json, tx_type) do
    tx_hash_json =
      case tx_type do
        :commit_tx -> batch_json.commit_tx_hash
        :prove_tx -> batch_json.prove_tx_hash
        :execute_tx -> batch_json.executed_tx_hash
      end
    tx_hash_db =
      case tx_type do
        :commit_tx -> batch_db.commit_transaction
        :prove_tx -> batch_db.prove_transaction
        :execute_tx -> batch_db.execute_transaction
      end
    tx_hash_db =
      if is_nil(tx_hash_db) do
        @zero_hash_binary
      else
        tx_hash_db.hash.bytes
      end
    tx_hash_json != tx_hash_db
  end

  defp handle_batch_range(start_batch_number, end_batch_number, config) do
    batches_details = collect_batches_details(start_batch_number, end_batch_number, config)
    log_info("Collected details for #{length(Map.keys(batches_details))} batches")

    batches_to_import =
      Reader.batches(
        start_batch_number,
        end_batch_number,
        necessity_by_association: %{
          :commit_transaction => :optional,
          :prove_transaction => :optional,
          :execute_transaction => :optional
        }
      )
      |> Enum.reduce(batches_details, fn batch_from_db, changed_batches ->
        received_batch = Map.get(batches_details, batch_from_db.number)
        if is_transactions_of_batch_changed(batch_from_db, received_batch, :commit_tx) &&
           is_transactions_of_batch_changed(batch_from_db, received_batch, :prove_tx) &&
           is_transactions_of_batch_changed(batch_from_db, received_batch, :execute_tx) do
          Map.delete(changed_batches, batch_from_db.number)
        else
          received_batch =
            Map.merge(
              received_batch,
              %{
                start_block: batch_from_db.start_block,
                end_block: batch_from_db.end_block
              }
            )
          Map.put(changed_batches, batch_from_db.number, received_batch)
        end
      end)
    IO.inspect(batches_to_import)

    # Receive all indexed batches from start_batch_number to end_batch_number
    # Make sure that all L1 tx ids are extended with L1 tx hashes

    # Transform batches_details to a map which does not contain batches with
    # commit_tx_hash, commit_timestamp, prove_tx_hash, prove_timestamp,
    # executed_tx_hash and executed_timestamp unchanged
    # Makes sure that the new field "l1_updated" contains one of the following:
    # :commit, :commit_prove, :commit_execute, :prove, :prove_execute
    # :execute, :commit_prove_execute
    # depending on the life cycle update
    # start_block and end_block must be copied from the the indexed batches

    {batches_to_import, l1_txs} =
      extract_l1_tx_and_get_block_ranges(batches_to_import, config)
    log_info("Collected #{length(Map.keys(l1_txs))} L1 hashes")

    { l2_blocks_to_import, l2_txs_to_import } =
      get_l2_blocks_and_transactions(batches_to_import, config)
    log_info("Linked #{length(l2_blocks_to_import)} L2 blocks and #{length(l2_txs_to_import)} L2 transactions")

    {batches_list_to_import, latest_finalized} =
      Map.keys(batches_to_import)
      |> Enum.reduce({[], 0}, fn batch_number, {batches_list, latest_finalized} ->
        batch = Map.get(batches_to_import, batch_number)
        latest_finalized =
          if (batch.executed_tx_hash != @zero_hash_binary) and (batch_number > latest_finalized) do
            batch_number
          else
            latest_finalized
          end
        {
          [ batch
            |> Map.put(:commit_id, get_l1_tx_id_by_hash(l1_txs, batch.commit_tx_hash))
            |> Map.put(:prove_id, get_l1_tx_id_by_hash(l1_txs, batch.prove_tx_hash))
            |> Map.put(:execute_id, get_l1_tx_id_by_hash(l1_txs, batch.executed_tx_hash))
            |> Map.drop([:commit_tx_hash, :commit_timestamp, :prove_tx_hash, :prove_timestamp, :executed_tx_hash, :executed_timestamp]) | batches_list ],
          latest_finalized
        }
      end)

    {:ok, _} =
      Chain.import(%{
        zksync_lifecycle_transactions: %{params: Map.values(l1_txs)},
        zksync_transaction_batches: %{params: batches_list_to_import},
        timeout: :infinity
      })

    # fetch_and_save_batches(chunk_start, chunk_end, json_rpc_named_arguments)
    if latest_finalized > 0 do
      latest_finalized
    else
      start_batch_number - 1
    end
  end

  defp get_l1_tx_id_by_hash(l1_txs, hash) do
    l1_txs
    |> Map.get(hash)
    |> Kernel.||(%{id: nil})
    |> Map.get(:id)
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
