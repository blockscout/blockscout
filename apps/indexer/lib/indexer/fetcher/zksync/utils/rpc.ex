defmodule Indexer.Fetcher.ZkSync.Utils.Rpc do
  @moduledoc """
    Common functions to handle RPC calls for Indexer.Fetcher.ZkSync fetchers
  """

  import EthereumJSONRPC, only: [json_rpc: 2, quantity_to_integer: 1]

  alias ABI.{FunctionSelector, TypeDecoder}
  alias EthereumJSONRPC.ZkSync.Constants.Contracts, as: ZkSyncContracts
  alias Explorer.Chain.Hash
  alias Indexer.Helper, as: IndexerHelper

  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_error: 1, log_info: 1]

  @zero_hash "0000000000000000000000000000000000000000000000000000000000000000"
  @zero_hash_binary <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

  @rpc_resend_attempts 20

  def get_zero_hash do
    @zero_hash
  end

  def get_binary_zero_hash do
    @zero_hash_binary
  end

  @doc """
    Filters out logs from a list of transactions logs where topic #0 is `topic_0` and
    builds a list of values located at position `position` in such logs.

    ## Parameters
    - `logs`: The list of transaction logs to filter logs with a specific topic.
    - `topic_0`: The value of topic #0 in the required logs.
    - `position`: The topic number to be extracted from the topic lists of every log
                  and appended to the resulting list.

    ## Returns
    - A list of values extracted from the required transaction logs.
    - An empty list if no logs with the specified topic are found.
  """
  @spec filter_logs_and_extract_topic_at(maybe_improper_list(), binary(), integer()) :: list()
  def filter_logs_and_extract_topic_at(logs, topic_0, position)
      when is_list(logs) and
             is_binary(topic_0) and
             (is_integer(position) and position >= 0 and position <= 3) do
    logs
    |> Enum.reduce([], fn log_entity, result ->
      topics = log_entity["topics"]

      if Enum.at(topics, 0) == topic_0 do
        [quantity_to_integer(Enum.at(topics, position)) | result]
      else
        result
      end
    end)
  end

  defp from_iso8601_to_datetime(time_string) do
    case is_nil(time_string) do
      true ->
        IndexerHelper.timestamp_to_datetime(0)

      false ->
        case DateTime.from_iso8601(time_string) do
          {:ok, datetime, _} ->
            datetime

          {:error, _} ->
            IndexerHelper.timestamp_to_datetime(0)
        end
    end
  end

  defp json_transaction_id_to_hash(hash) do
    case hash do
      "0x" <> transaction_hash -> transaction_hash
      nil -> @zero_hash
    end
  end

  defp string_hash_to_bytes_hash(hash) do
    hash
    |> json_transaction_id_to_hash()
    |> Base.decode16!(case: :mixed)
  end

  @doc """
    Transforms a map with batch data received from the `zks_getL1BatchDetails` call
    into a map that can be used by Indexer.Fetcher.ZkSync fetchers for further handling.
    All hexadecimal hashes are converted to their decoded binary representation,
    Unix and ISO8601 timestamps are converted to DateTime objects.

    ## Parameters
    - `json_response`: Raw data received from the JSON RPC call.

    ## Returns
    - A map containing minimal information about the batch. `start_block` and `end_block`
      elements are set to `nil`.
  """
  @spec transform_batch_details_to_map(map()) :: map()
  def transform_batch_details_to_map(json_response)
      when is_map(json_response) do
    %{
      "number" => {:number, :ok},
      "timestamp" => {:timestamp, :ts_to_datetime},
      "l1TxCount" => {:l1_transaction_count, :ok},
      "l2TxCount" => {:l2_transaction_count, :ok},
      "rootHash" => {:root_hash, :str_to_byteshash},
      "commitTxHash" => {:commit_transaction_hash, :str_to_byteshash},
      "committedAt" => {:commit_timestamp, :iso8601_to_datetime},
      "proveTxHash" => {:prove_transaction_hash, :str_to_byteshash},
      "provenAt" => {:prove_timestamp, :iso8601_to_datetime},
      "executeTxHash" => {:executed_transaction_hash, :str_to_byteshash},
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
          :ts_to_datetime -> IndexerHelper.timestamp_to_datetime(value_in_json_response)
          :str_to_txhash -> json_transaction_id_to_hash(value_in_json_response)
          :str_to_byteshash -> string_hash_to_bytes_hash(value_in_json_response)
          _ -> value_in_json_response
        end
      )
    end)
  end

  @doc """
    Transforms a map with batch data received from the database into a map that
    can be used by Indexer.Fetcher.ZkSync fetchers for further handling.

    ## Parameters
    - `batch`: A map containing a batch description received from the database.

    ## Returns
    - A map containing simplified representation of the batch. Compatible with
      the database import operation.
  """
  def transform_transaction_batch_to_map(batch)
      when is_map(batch) do
    %{
      number: batch.number,
      timestamp: batch.timestamp,
      l1_transaction_count: batch.l1_transaction_count,
      l2_transaction_count: batch.l2_transaction_count,
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

  @doc """
    Retrieves batch details from the RPC endpoint using the `zks_getL1BatchDetails` call.

    ## Parameters
    - `batch_number`: The batch number or identifier.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - A map containing minimal batch details. It includes `start_block` and `end_block`
      elements, both set to `nil`.
  """
  @spec fetch_batch_details_by_batch_number(binary() | non_neg_integer(), EthereumJSONRPC.json_rpc_named_arguments()) ::
          map()
  def fetch_batch_details_by_batch_number(batch_number, json_rpc_named_arguments)
      when (is_integer(batch_number) or is_binary(batch_number)) and is_list(json_rpc_named_arguments) do
    req =
      EthereumJSONRPC.request(%{
        id: batch_number,
        method: "zks_getL1BatchDetails",
        params: [batch_number]
      })

    error_message = &"Cannot call zks_getL1BatchDetails. Error: #{inspect(&1)}"

    {:ok, resp} =
      IndexerHelper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, @rpc_resend_attempts)

    transform_batch_details_to_map(resp)
  end

  @doc """
    Fetches transaction details from the RPC endpoint using the `eth_getTransactionByHash` call.

    ## Parameters
    - `raw_hash`: The hash of the Ethereum transaction. It can be provided as a decoded binary
                  or hexadecimal string.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - A map containing details of the transaction.
  """
  @spec fetch_transaction_by_hash(binary(), EthereumJSONRPC.json_rpc_named_arguments()) :: map()
  def fetch_transaction_by_hash(raw_hash, json_rpc_named_arguments)
      when is_binary(raw_hash) and is_list(json_rpc_named_arguments) do
    {:ok, hash} = Hash.Full.cast(raw_hash)

    req =
      EthereumJSONRPC.request(%{
        id: 0,
        method: "eth_getTransactionByHash",
        params: [hash]
      })

    error_message = &"Cannot call eth_getTransactionByHash for hash #{hash}. Error: #{inspect(&1)}"

    {:ok, resp} =
      IndexerHelper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, @rpc_resend_attempts)

    resp
  end

  @doc """
    Fetches the transaction receipt from the RPC endpoint using the `eth_getTransactionReceipt` call.

    ## Parameters
    - `raw_hash`: The hash of the Ethereum transaction. It can be provided as a decoded binary
                  or hexadecimal string.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - A map containing the receipt details of the transaction.
  """
  @spec fetch_transaction_receipt_by_hash(binary(), EthereumJSONRPC.json_rpc_named_arguments()) :: map()
  def fetch_transaction_receipt_by_hash(raw_hash, json_rpc_named_arguments)
      when is_binary(raw_hash) and is_list(json_rpc_named_arguments) do
    {:ok, hash} = Hash.Full.cast(raw_hash)

    req =
      EthereumJSONRPC.request(%{
        id: 0,
        method: "eth_getTransactionReceipt",
        params: [hash]
      })

    error_message = &"Cannot call eth_getTransactionReceipt for hash #{hash}. Error: #{inspect(&1)}"

    {:ok, resp} =
      IndexerHelper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, @rpc_resend_attempts)

    resp
  end

  @doc """
    Fetches the latest sealed batch number from the RPC endpoint using the `zks_L1BatchNumber` call.

    ## Parameters
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - A non-negative integer representing the latest sealed batch number.
  """
  @spec fetch_latest_sealed_batch_number(EthereumJSONRPC.json_rpc_named_arguments()) :: nil | non_neg_integer()
  def fetch_latest_sealed_batch_number(json_rpc_named_arguments)
      when is_list(json_rpc_named_arguments) do
    req = EthereumJSONRPC.request(%{id: 0, method: "zks_L1BatchNumber", params: []})

    error_message = &"Cannot call zks_L1BatchNumber. Error: #{inspect(&1)}"

    {:ok, resp} =
      IndexerHelper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, @rpc_resend_attempts)

    quantity_to_integer(resp)
  end

  @doc """
    Fetches block details using multiple `eth_getBlockByNumber` RPC calls.

    ## Parameters
    - `requests_list`: A list of `EthereumJSONRPC.Transport.request()` representing multiple
      `eth_getBlockByNumber` RPC calls for different block numbers.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - A list of responses containing details of the requested blocks.
  """
  @spec fetch_blocks_details([EthereumJSONRPC.Transport.request()], EthereumJSONRPC.json_rpc_named_arguments()) ::
          list()
  def fetch_blocks_details(requests_list, json_rpc_named_arguments)

  def fetch_blocks_details([], _) do
    []
  end

  def fetch_blocks_details(requests_list, json_rpc_named_arguments)
      when is_list(requests_list) and is_list(json_rpc_named_arguments) do
    error_message = &"Cannot call eth_getBlockByNumber. Error: #{inspect(&1)}"

    {:ok, responses} =
      IndexerHelper.repeated_call(
        &json_rpc/2,
        [requests_list, json_rpc_named_arguments],
        error_message,
        @rpc_resend_attempts
      )

    responses
  end

  @doc """
    Fetches batches details using multiple `zks_getL1BatchDetails` RPC calls.

    ## Parameters
    - `requests_list`: A list of `EthereumJSONRPC.Transport.request()` representing multiple
      `zks_getL1BatchDetails` RPC calls for different block numbers.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - A list of responses containing details of the requested batches.
  """
  @spec fetch_batches_details([EthereumJSONRPC.Transport.request()], EthereumJSONRPC.json_rpc_named_arguments()) ::
          list()
  def fetch_batches_details(requests_list, json_rpc_named_arguments)

  def fetch_batches_details([], _) do
    []
  end

  def fetch_batches_details(requests_list, json_rpc_named_arguments)
      when is_list(requests_list) and is_list(json_rpc_named_arguments) do
    error_message = &"Cannot call zks_getL1BatchDetails. Error: #{inspect(&1)}"

    {:ok, responses} =
      IndexerHelper.repeated_call(
        &json_rpc/2,
        [requests_list, json_rpc_named_arguments],
        error_message,
        @rpc_resend_attempts
      )

    responses
  end

  @doc """
    Fetches block ranges included in the specified batches by using multiple
    `zks_getL1BatchBlockRange` RPC calls.

    ## Parameters
    - `requests_list`: A list of `EthereumJSONRPC.Transport.request()` representing multiple
      `zks_getL1BatchBlockRange` RPC calls for different batch numbers.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - A list of responses containing block ranges associated with the requested batches.
  """
  @spec fetch_blocks_ranges([EthereumJSONRPC.Transport.request()], EthereumJSONRPC.json_rpc_named_arguments()) ::
          list()
  def fetch_blocks_ranges(requests_list, json_rpc_named_arguments)

  def fetch_blocks_ranges([], _) do
    []
  end

  def fetch_blocks_ranges(requests_list, json_rpc_named_arguments)
      when is_list(requests_list) and is_list(json_rpc_named_arguments) do
    error_message = &"Cannot call zks_getL1BatchBlockRange. Error: #{inspect(&1)}"

    {:ok, responses} =
      IndexerHelper.repeated_call(
        &json_rpc/2,
        [requests_list, json_rpc_named_arguments],
        error_message,
        @rpc_resend_attempts
      )

    responses
  end

  @doc """
    Extracts batch numbers from the calldata of a proof transaction.

    ## Parameters
    - `calldata`: The calldata from the parent chain transaction

    ## Returns
    - A list of batch numbers that were proven by the transaction
  """
  @spec get_proven_batches_from_calldata(binary()) :: [non_neg_integer()]
  def get_proven_batches_from_calldata(calldata) do
    proven_batches =
      case calldata do
        "0x7f61885c" <> encoded_params ->
          [_prev_batch, proven_batches, _proof] =
            decode_params(encoded_params, ZkSyncContracts.prove_batches_selector_with_abi())

          extract_batch_numbers(proven_batches)

        # Pre-v26 proveBatchesSharedBridge
        "0xc37533bb" <> encoded_params ->
          [_chainid, _prev_batch, proven_batches, _proof] =
            decode_params(encoded_params, ZkSyncContracts.prove_batches_shared_bridge_c37533bb_selector_with_abi())

          extract_batch_numbers(proven_batches)

        # v26+ proveBatchesSharedBridge
        "0xe12a6137" <> encoded_params ->
          [_chainid, process_from, process_to, _proof_data] =
            decode_params(encoded_params, ZkSyncContracts.prove_batches_shared_bridge_e12a6137_selector_with_abi())

          Enum.to_list(process_from..process_to)

        _ ->
          log_error("Unknown calldata format: #{calldata}")

          []
      end

    log_info("Discovered #{length(proven_batches)} proven batches in the prove transaction")

    proven_batches
  end

  # Decodes encoded parameters using the provided function selector.
  # credo:disable-for-next-line Credo.Check.Warning.SpecWithStruct
  @spec decode_params(binary(), %FunctionSelector{}) :: list()
  defp decode_params(encoded_params, function_selector) do
    encoded_params
    |> Base.decode16!(case: :lower)
    |> TypeDecoder.decode(function_selector)
  end

  # Extracts batch numbers from a list of StoredBatchInfo tuples.
  @spec extract_batch_numbers([any()]) :: [non_neg_integer()]
  defp extract_batch_numbers(proven_batches) do
    proven_batches
    |> Enum.map(fn batch_info -> elem(batch_info, 0) end)
  end
end
