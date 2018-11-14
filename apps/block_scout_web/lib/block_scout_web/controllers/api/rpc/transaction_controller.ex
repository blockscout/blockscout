defmodule BlockScoutWeb.API.RPC.TransactionController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  def gettxinfo(conn, params) do
    with {:txhash_param, {:ok, txhash_param}} <- fetch_txhash(params),
         {:format, {:ok, transaction_hash}} <- to_transaction_hash(txhash_param),
         {:transaction, {:ok, transaction}} <- transaction_from_hash(transaction_hash) do
      max_block_number = max_block_number()

      logs = Chain.transaction_to_logs(transaction)
      render(conn, :gettxinfo, %{transaction: transaction, max_block_number: max_block_number, logs: logs})
    else
      {:transaction, :error} ->
        render(conn, :error, error: "Transaction not found")

      {:txhash_param, :error} ->
        render(conn, :error, error: "Query parameter txhash is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid txhash format")
    end
  end

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

  def getstatus(conn, params) do
    with {:txhash_param, {:ok, txhash_param}} <- fetch_txhash(params),
         {:format, {:ok, transaction_hash}} <- to_transaction_hash(txhash_param) do
      error = to_transaction_error(transaction_hash)
      render(conn, :getstatus, %{error: error})
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

  defp transaction_from_hash(transaction_hash) do
    case Chain.hash_to_transaction(transaction_hash, necessity_by_association: %{block: :required}) do
      {:error, :not_found} -> {:transaction, :error}
      {:ok, transaction} -> {:transaction, {:ok, transaction}}
    end
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

  defp to_transaction_error(transaction_hash) do
    with {:ok, transaction} <- Chain.hash_to_transaction(transaction_hash),
         {:error, error} <- Chain.transaction_to_status(transaction) do
      error
    else
      _ -> ""
    end
  end

  defp max_block_number do
    case Chain.max_block_number() do
      {:ok, number} -> number
      {:error, :not_found} -> 0
    end
  end
end
