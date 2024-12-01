defmodule Indexer.Fetcher.OnDemand.NeonSolanaTransactions do
  require Logger

  import Ecto.Query, only: [from: 2]
  alias Explorer.Chain.Neon.LinkedSolanaTransactions
  alias Explorer.Repo

  def trigger_fetch(transaction_hash) do
    arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)

    with {:ok, linked_transactions} <- EthereumJSONRPC.get_linked_solana_transactions(transaction_hash, arguments) do
      {:ok, linked_transactions}
    else
      {:error, reason} -> {:error, "unable to fetch data from the node: #{inspect(reason)}"}
    end
  end

  def query_from_db(decoded_transaction_hash) do
    from(
      solanaTransaction in LinkedSolanaTransactions,
      where: solanaTransaction.neon_transaction_hash == ^decoded_transaction_hash,
      select: solanaTransaction.solana_transaction_hash
    )
    |> Repo.all()
  end

  @spec maybe_fetch(EthereumJSONRPC.hash()) :: {:ok,list}  | {:error, String.t()}
  def maybe_fetch(transaction_hash) do
    transaction_hash = normalize(transaction_hash)

    with {:ok, decoded_transaction_hash} <- Base.decode16(transaction_hash, case: :lower) do
      with results when results != [] <- query_from_db(decoded_transaction_hash) do
        {:ok, results}
      else
        [] ->
          with {:ok, fetched} <- trigger_fetch(transaction_hash) do
            Repo.transaction(fn ->
              Enum.each(fetched, fn sol_transaction_hash_string ->
                changeset =
                  Explorer.Chain.Neon.LinkedSolanaTransactions.changeset(
                    %Explorer.Chain.Neon.LinkedSolanaTransactions{},
                    %{
                      neon_transaction_hash: decoded_transaction_hash,
                      solana_transaction_hash: sol_transaction_hash_string
                    }
                  )

                Repo.insert!(changeset)
              end)
            end)

            {:ok, fetched}
          else
            {:error, reason} -> {:error, "Failed to fetch or insert: #{inspect(reason)}"}
          end

        {:error, reason} ->
          {:error, "Failed to query linked transactions: #{inspect(reason)}"}
      end
    end
  end

  defp normalize(hex_string) do
    case hex_string do
      "0x" <> rest -> rest
      hex -> hex
    end
  end
end
