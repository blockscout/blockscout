defmodule Indexer.Fetcher.ZkSync.Helper do
  @moduledoc """
    Common functions for Indexer.Fetcher.ZkSync fetchers
  """
  require Logger

  import EthereumJSONRPC, only: [json_rpc: 2, quantity_to_integer: 1]

  @zero_hash "0000000000000000000000000000000000000000000000000000000000000000"
  @zero_hash_binary <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

  def get_zero_hash do
    @zero_hash
  end

  def get_binary_zero_hash do
    @zero_hash_binary
  end

  def get_2map_data(map, key1, key2) do
    case Map.get(map, key1) do
      nil -> nil
      inner_map -> Map.get(inner_map, key2)
    end
  end

  def filter_logs_and_extract_topic_at(logs, topic_0, position)
    when is_list(logs) and
         is_binary(topic_0) and
         is_integer(position) do
    logs
    |> Enum.reduce([], fn log_entity, result ->
      topics = log_entity["topics"]
      if Enum.at(topics, 0) == topic_0 do
        [ quantity_to_integer(Enum.at(topics, position)) | result]
      else
        result
      end
    end)
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

  def transform_batch_details_to_map(json_response) do
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

  def transform_transaction_batch_to_map(batch) do
    %{
      number: batch.number,
      timestamp: batch.timestamp,
      l1_tx_count: batch.l1_tx_count,
      l2_tx_count: batch.l2_tx_count,
      root_hash: batch.root_hash.bytes,
      l1_gas_price: batch.l1_gas_price,
      l2_fair_gas_price: batch.l2_fair_gas_price,
      start_block: batch.start_block,
      end_block: batch.end_block,
      commit_id: batch.commit_id,
      prove_id: batch.prove_id,
      execute_id: batch.execute_id
    }
  end

  def fetch_batch_details_by_batch_number(batch_number, json_rpc_named_arguments) do
    req = EthereumJSONRPC.request(%{
      id: batch_number,
      method: "zks_getL1BatchDetails",
      params: [batch_number]
    })

    error_message = &"Cannot call zks_getL1BatchDetails. Error: #{inspect(&1)}"

    {:ok, resp} = repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, 3)

    transform_batch_details_to_map(resp)
  end

  def fetch_tx_by_hash(hash, json_rpc_named_arguments) do
    req = EthereumJSONRPC.request(%{
      id: 0,
      method: "eth_getTransactionByHash",
      params: [hash]
    })

    error_message = &"Cannot call eth_getTransactionByHash for hash #{hash}. Error: #{inspect(&1)}"

    {:ok, resp} = repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, 3)

    resp
  end

  def fetch_tx_receipt_by_hash(hash, json_rpc_named_arguments) do
    req = EthereumJSONRPC.request(%{
      id: 0,
      method: "eth_getTransactionReceipt",
      params: [hash]
    })

    error_message = &"Cannot call eth_getTransactionReceipt for hash #{hash}. Error: #{inspect(&1)}"

    {:ok, resp} = repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, 3)

    resp
  end

  def fetch_latest_sealed_batch_number(json_rpc_named_arguments) do
    req = EthereumJSONRPC.request(%{id: 0, method: "zks_L1BatchNumber", params: []})

    error_message = &"Cannot call zks_L1BatchNumber. Error: #{inspect(&1)}"

    {:ok, resp} = repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, 3)

    quantity_to_integer(resp)
  end

  def fetch_blocks_details([], _) do
    []
  end

  def fetch_blocks_details(requests_list, json_rpc_named_arguments)
      when is_list(requests_list) do
    error_message =
      &"Cannot call eth_getBlockByNumber. Error: #{inspect(&1)}"

    {:ok, responses} = repeated_call(&json_rpc/2, [requests_list, json_rpc_named_arguments], error_message, 3)

    responses
  end

  def fetch_batches_details([], _) do
    []
  end

  def fetch_batches_details(requests_list, json_rpc_named_arguments)
      when is_list(requests_list) do
    error_message =
      &"Cannot call zks_getL1BatchDetails. Error: #{inspect(&1)}"

    {:ok, responses} = repeated_call(&json_rpc/2, [requests_list, json_rpc_named_arguments], error_message, 3)

    responses
  end

  def fetch_blocks_ranges([], _) do
    []
  end

  def fetch_blocks_ranges(requests_list, json_rpc_named_arguments)
      when is_list(requests_list) do
    error_message =
      &"Cannot call zks_getL1BatchBlockRange. Error: #{inspect(&1)}"

    {:ok, responses} = repeated_call(&json_rpc/2, [requests_list, json_rpc_named_arguments], error_message, 3)

    responses
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

  ###############################################################################
  ##### Logging related functions
  def log_warning(msg) do
    Logger.warning(msg)
  end

  def log_info(msg) do
    Logger.notice(msg)
  end

  def log_details_chunk_handling(prefix, chunk, current_progress, total) do
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
    if chunk_length == 1 do
      log_info("#{prefix} for batch ##{Enum.at(chunk, 0)}")
    else
      log_info("#{prefix} for batches #{Enum.join(shorten_numbers_list(chunk), ", ")}.#{progress}")
    end

  end

  defp shorten_numbers_list_impl(number, shorten_list, prev_range_start, prev_number) do
    cond do
      is_nil(prev_number) -> {[], number, number}
      prev_number + 1 != number and prev_range_start == prev_number -> {[ "#{prev_range_start}" | shorten_list ], number, number}
      prev_number + 1 != number -> {[ "#{prev_range_start}..#{prev_number}" | shorten_list ], number, number}
      true -> {shorten_list, prev_range_start, number}
    end
  end

  defp shorten_numbers_list(numbers_list) do
    {shorten_list, _, _} =
      Enum.sort(numbers_list)
      |> Enum.reduce({[], nil, nil}, fn number, {shorten_list, prev_range_start, prev_number} ->
        shorten_numbers_list_impl(number, shorten_list, prev_range_start, prev_number)
      end)
      |> then(fn {shorten_list, prev_range_start, prev_number} ->
        shorten_numbers_list_impl(prev_number, shorten_list, prev_range_start, prev_number)
      end)
    Enum.reverse(shorten_list)
  end

end
