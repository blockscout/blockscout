defmodule Indexer.BlockFetcher.Receipts do
  @moduledoc """
  Fetches transaction receipts after the transactions have been fetched with the blocks in `Indexer.BlockFetcher`.
  """

  import Indexer, only: [debug: 1]

  alias Indexer.BlockFetcher

  def fetch(%BlockFetcher{} = _state, []), do: {:ok, %{logs: [], receipts: []}}

  def fetch(
        %BlockFetcher{json_rpc_named_arguments: json_rpc_named_arguments} = state,
        transaction_params
      ) do
    debug(fn -> "fetching #{length(transaction_params)} transaction receipts" end)
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
  end

  def put(transactions_params, receipts_params) when is_list(transactions_params) and is_list(receipts_params) do
    transaction_hash_to_receipt_params =
      Enum.into(receipts_params, %{}, fn %{transaction_hash: transaction_hash} = receipt_params ->
        {transaction_hash, receipt_params}
      end)

    Enum.map(transactions_params, fn %{hash: transaction_hash} = transaction_params ->
      Map.merge(transaction_params, Map.fetch!(transaction_hash_to_receipt_params, transaction_hash))
    end)
  end
end
