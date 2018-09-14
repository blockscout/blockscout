defmodule BlockScoutWeb.API.RPC.TransactionController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  def gettxreceiptstatus(conn, params) do
    with {:txhash_param, {:ok, txhash_param}} <- fetch_txhash(params),
         {:format, {:ok, transaction_hash}} <- to_transaction_hash(txhash_param) do
      status = to_transaction_status(transaction_hash)
      render(conn, :gettxreceiptstatus, %{status: status})
    else
      {:txhash_param, :error} ->
        render(conn, :error, error: "Query parameter txhash is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid txhash format")
    end
  end

  defp fetch_txhash(params) do
    {:txhash_param, Map.fetch(params, "txhash")}
  end

  defp to_transaction_hash(transaction_hash_string) do
    {:format, Chain.string_to_transaction_hash(transaction_hash_string)}
  end

  defp to_transaction_status(transaction_hash) do
    case Chain.hash_to_transaction(transaction_hash) do
      {:error, :not_found} -> ""
      {:ok, transaction} -> transaction.status
    end
  end
end
