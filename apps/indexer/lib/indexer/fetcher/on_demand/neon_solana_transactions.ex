defmodule Indexer.Fetcher.OnDemand.NeonSolanaTransactions do
  @moduledoc """
  A caching proxy service getting linked solana transactions from NeonEVM Node.
  The corresponding node data is available only via a dedicated endpoint
  so we don't fetch those unless a user explicitly requests so to minimize requests.
  ## Caching Behavior
  Fetched transactions are cached indefinitely in the database. There is no automatic cache invalidation.
  ## Transaction Hash Format
  Transaction hashes can be provided with or without "0x" prefix. The prefix will be automatically
  removed before processing.
  """
  require Logger

  import Ecto.Query, only: [from: 2]
  alias Explorer.Chain.Neon.LinkedSolanaTransactions
  alias Explorer.Repo

  defp trigger_fetch(transaction_hash) do
    arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)

    case EthereumJSONRPC.get_linked_solana_transactions(transaction_hash, arguments) do
      {:ok, fetched} when is_list(fetched) ->
        save_cache(transaction_hash, fetched)
        {:ok, fetched}

      {:error, reason} ->
        {:error, "Unable to fetch data from the node: #{inspect(reason)}"}
    end
  end

  defp cache(transaction_hash) do
    Repo.replica().all(
      from(
        solanaTransaction in LinkedSolanaTransactions,
        where: solanaTransaction.neon_transaction_hash == ^transaction_hash.bytes,
        select: solanaTransaction.solana_transaction_hash
      )
    )
  rescue
    e in Ecto.QueryError ->
      Logger.warning("Failed to query cached external transactions: #{inspect(e)}")
      []
  end

  defp save_cache(transaction_hash, fetched) do
    entries =
      Enum.map(fetched, fn sol_transaction_hash_string ->
        %{
          neon_transaction_hash: transaction_hash.bytes,
          solana_transaction_hash: sol_transaction_hash_string,
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end)

    case Repo.transaction(fn ->
           Repo.insert_all(
             LinkedSolanaTransactions,
             entries,
             on_conflict: :nothing,
             conflict_target: [:neon_transaction_hash, :solana_transaction_hash]
           )
         end) do
      {:ok, _result} ->
        nil

      {:error, reason} ->
        Logger.warning(
          "Failed to save linked Solana transactions: #{inspect(reason)} for transaction hash: #{to_string(transaction_hash)}"
        )
    end
  end

  @spec maybe_fetch(Explorer.Chain.Hash.t()) :: {:ok, list} | {:error, String.t()}
  def maybe_fetch(transaction_hash) do
    case cache(transaction_hash) do
      cached_data when cached_data != [] ->
        {:ok, cached_data}

      [] ->
        trigger_fetch(transaction_hash)
    end
  end
end
