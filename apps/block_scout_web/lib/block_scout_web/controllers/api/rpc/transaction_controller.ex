defmodule BlockScoutWeb.API.RPC.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias Explorer.Chain
  alias Explorer.Chain.{DenormalizationHelper, Transaction}

  @api_true [api?: true]

  def gettxinfo(conn, params) do
    with {:txhash_param, {:ok, txhash_param}} <- fetch_transaction_hash(params),
         {:format, {:ok, transaction_hash}} <- to_transaction_hash(txhash_param),
         {:transaction, {:ok, %Transaction{revert_reason: revert_reason, error: error} = transaction}} <-
           transaction_from_hash(transaction_hash),
         paging_options <- paging_options(params) do
      logs = Chain.transaction_to_logs(transaction_hash, Keyword.merge(paging_options, @api_true))
      {logs, next_page} = split_list_by_page(logs)

      transaction_updated =
        if (error == "Reverted" || error == "execution reverted") && !revert_reason do
          %Transaction{transaction | revert_reason: Chain.fetch_transaction_revert_reason(transaction)}
        else
          transaction
        end

      render(conn, :gettxinfo, %{
        transaction: transaction_updated,
        block_height: Chain.block_height(),
        logs: logs,
        next_page_params: next_page_params(next_page, logs, params)
      })
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
    with {:txhash_param, {:ok, txhash_param}} <- fetch_transaction_hash(params),
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
    with {:txhash_param, {:ok, txhash_param}} <- fetch_transaction_hash(params),
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

  defp fetch_transaction_hash(params) do
    {:txhash_param, Map.fetch(params, "txhash")}
  end

  defp transaction_from_hash(transaction_hash) do
    case Chain.hash_to_transaction(transaction_hash, DenormalizationHelper.extend_block_necessity([], :required)) do
      {:error, :not_found} -> {:transaction, :error}
      {:ok, transaction} -> {:transaction, {:ok, transaction}}
    end
  end

  defp to_transaction_hash(transaction_hash_string) do
    {:format, Chain.string_to_full_hash(transaction_hash_string)}
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
end
