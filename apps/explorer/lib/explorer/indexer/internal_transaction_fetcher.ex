defmodule Explorer.Indexer.InternalTransactionFetcher do
  @moduledoc """
  Fetches and indexes `t:Explorer.Chain.InternalTransaction.t/0`.
  """

  alias Explorer.{BufferedTask, Chain}
  alias Explorer.Chain.{Hash, Transaction}

  @behaviour BufferedTask

  def async_fetch(transactions) do
    string_hashes =
      Enum.map(transactions, fn %Transaction{hash: hash} ->
        Hash.to_string(hash)
      end)

    BufferedTask.buffer(__MODULE__, string_hashes)
  end

  def init(acc, reducer) do
    Chain.stream_transactions_with_unfetched_internal_transactions(acc, fn %Transaction{hash: hash}, acc ->
      reducer.(Hash.to_string(hash), acc)
    end)
  end

  def run(transaction_hashes, _retries) do
    case EthereumJSONRPC.fetch_internal_transactions(transaction_hashes) do
      {:ok, internal_params} ->
        {:ok, _} = Chain.import_internal_transactions(internal_params)

        :ok

      {:error, reason} ->
        {:retry, reason}
    end
  end
end
