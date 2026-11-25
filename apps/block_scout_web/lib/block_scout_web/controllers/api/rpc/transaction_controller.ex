# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.RPC.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1]
  import BlockScoutWeb.LegacyPagingHelper, only: [next_page_params: 3, split_list_by_page: 2]

  alias Explorer.Chain
  alias Explorer.Chain.{DenormalizationHelper, Transaction}

  @api_true [api?: true]

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

  @doc """
  Handles the `gettxinfo` action of the `transaction` module.

  Responds with the transaction identified by the `txhash` query parameter
  together with a page of its logs.
  """
  @spec gettxinfo(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def gettxinfo(conn, %{"txhash" => txhash_param} = params) do
    case Chain.string_to_full_hash(txhash_param) do
      {:ok, transaction_hash} -> render_transaction_info(conn, transaction_hash, params)
      :error -> render(conn, :error, error: "Invalid txhash format")
    end
  end

  def gettxinfo(conn, _params), do: render(conn, :error, error: "Query parameter txhash is required")

  defp fetch_transaction_hash(params) do
    {:txhash_param, Map.fetch(params, "txhash")}
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

  # Responds with the transaction and the requested page of its logs, or with an
  # error when no transaction has the given hash.
  defp render_transaction_info(conn, transaction_hash, params) do
    case Chain.hash_to_transaction(transaction_hash, DenormalizationHelper.extend_block_necessity([], :required)) do
      {:ok, transaction} ->
        paging_options = paging_options(params)
        logs = Chain.transaction_to_logs(transaction_hash, Keyword.merge(paging_options, @api_true))
        {logs, next_page} = split_list_by_page(logs, paging_options[:paging_options])

        render(conn, :gettxinfo, %{
          transaction: with_revert_reason(transaction),
          block_height: Chain.block_height(),
          logs: logs,
          next_page_params: next_page_params(next_page, logs, params)
        })

      {:error, :not_found} ->
        render(conn, :error, error: "Transaction not found")
    end
  end

  # Fetches the revert reason of a reverted transaction if it is not stored yet.
  defp with_revert_reason(%Transaction{revert_reason: nil, error: error} = transaction)
       when error in ["Reverted", "execution reverted"] do
    %Transaction{transaction | revert_reason: Transaction.fetch_transaction_revert_reason(transaction)}
  end

  defp with_revert_reason(transaction), do: transaction
end
