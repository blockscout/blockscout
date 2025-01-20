defmodule Indexer.Block.Fetcher.Receipts do
  @moduledoc """
    Fetches and processes transaction receipts and logs for block indexing.

    Makes batched JSON-RPC requests to retrieve receipts and logs after initial
    block data is fetched. Provides configurable concurrency and batch sizes for
    optimized fetching.
  """

  require Logger

  alias Indexer.Block

  @doc """
    Fetches transaction receipts and logs in batches with configurable concurrency.

    Processes transaction parameters in chunks, making concurrent requests to retrieve
    receipts and logs. Empty transaction lists return empty results immediately.

    ## Parameters
    - `state`: Block fetcher state containing JSON-RPC, concurrency and batch size
      configuration
    - `transaction_params`: List of transaction parameter maps to fetch receipts for

    ## Returns
    - `{:ok, %{logs: list(), receipts: list()}}` - Successfully fetched receipts
      and logs with block numbers added where missing
    - `{:error, reason}` - Error occurred during fetch or processing
  """
  @spec fetch(Block.Fetcher.t(), [map()]) :: {:ok, %{logs: [map()], receipts: [map()]}} | {:error, term()}
  def fetch(state, transaction_params)

  def fetch(%Block.Fetcher{} = _state, []), do: {:ok, %{logs: [], receipts: []}}

  def fetch(
        %Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = state,
        transaction_params
      ) do
    Logger.debug("fetching transaction receipts", count: Enum.count(transaction_params))
    stream_opts = [max_concurrency: state.receipts_concurrency, timeout: :infinity]

    transaction_params
    |> Enum.chunk_every(state.receipts_batch_size)
    |> Task.async_stream(&EthereumJSONRPC.fetch_transaction_receipts(&1, json_rpc_named_arguments), stream_opts)
    |> Enum.reduce_while({:ok, %{logs: [], receipts: []}}, fn
      {:ok, {:ok, %{logs: logs, receipts: receipts}}}, {:ok, %{logs: acc_logs, receipts: acc_receipts}} ->
        {:cont, {:ok, %{logs: acc_logs ++ logs, receipts: acc_receipts ++ receipts}}}

      {:ok, {:error, reason}}, {:ok, _acc} ->
        {:halt, {:error, reason}}

      {:error, reason}, {:ok, _acc} ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, receipt_params} -> {:ok, set_block_number_to_logs(receipt_params, transaction_params)}
      other -> other
    end
  end

  @doc """
    Merges transaction receipts with their corresponding transactions.

    Combines transaction parameters with receipt parameters, preserving the original
    created contract address if the receipt would override it with nil.

    ## Parameters
    - `transactions_params`: List of transaction parameter maps
    - `receipts_params`: List of receipt parameter maps

    ## Returns
    - List of merged transaction maps containing both transaction and receipt data
  """
  @spec put(
          [%{required(:hash) => EthereumJSONRPC.hash(), optional(atom()) => any()}],
          [%{required(:transaction_hash) => EthereumJSONRPC.hash(), optional(atom()) => any()}]
        ) :: [map()]
  def put(transactions_params, receipts_params) when is_list(transactions_params) and is_list(receipts_params) do
    transaction_hash_to_receipt_params =
      Enum.into(receipts_params, %{}, fn %{transaction_hash: transaction_hash} = receipt_params ->
        {transaction_hash, receipt_params}
      end)

    Enum.map(transactions_params, fn %{hash: transaction_hash} = transaction_params ->
      receipts_params = Map.fetch!(transaction_hash_to_receipt_params, transaction_hash)
      merged_params = Map.merge(transaction_params, receipts_params)

      # Preserve the created_contract_address_hash from transaction_params if receipts_params
      # would override it with nil
      if transaction_params[:created_contract_address_hash] && is_nil(receipts_params[:created_contract_address_hash]) do
        Map.put(merged_params, :created_contract_address_hash, transaction_params[:created_contract_address_hash])
      else
        merged_params
      end
    end)
  end

  # Updates block numbers in transaction logs by matching them with their parent transactions.
  #
  # For logs with missing block numbers, finds the corresponding transaction and copies its
  # block number to the log. Leaves logs with existing block numbers unchanged.
  #
  # ## Parameters
  # - `params`: Map containing logs and other optional data
  # - `transaction_params`: List of transaction parameter maps with block numbers
  #
  # ## Returns
  # - Updated params map with block numbers added to logs where missing
  @spec set_block_number_to_logs(
          %{:logs => list(), optional(atom()) => any()},
          [%{:hash => EthereumJSONRPC.hash(), optional(atom()) => any()}]
        ) :: %{:logs => list(), optional(atom()) => any()}
  defp set_block_number_to_logs(%{logs: logs} = params, transaction_params) do
    logs_with_block_numbers =
      Enum.map(logs, fn %{transaction_hash: transaction_hash, block_number: block_number} = log_params ->
        if is_nil(block_number) do
          transaction = find_transaction_by_hash(transaction_params, transaction_hash)

          %{log_params | block_number: transaction[:block_number]}
        else
          log_params
        end
      end)

    %{params | logs: logs_with_block_numbers}
  end

  # Finds a transaction in the list of transaction parameters by its hash.
  @spec find_transaction_by_hash(
          [%{:hash => EthereumJSONRPC.hash(), optional(atom()) => any()}],
          EthereumJSONRPC.hash()
        ) ::
          %{:hash => EthereumJSONRPC.hash(), optional(atom()) => any()} | nil
  defp find_transaction_by_hash(transaction_params, transaction_hash) do
    Enum.find(transaction_params, fn transaction ->
      transaction[:hash] == transaction_hash
    end)
  end
end
