defmodule BlockScoutWeb.API.V2.InternalTransactionController do
  use BlockScoutWeb, :controller
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.InternalTransaction
  alias Explorer.{Chain, Helper, PagingOptions}

  import BlockScoutWeb.Chain,
    only: [
      split_list_by_page: 1,
      paging_options: 1,
      next_page_params: 3
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      delete_parameters_from_next_page_params: 1
    ]

  import Explorer.PagingOptions, only: [default_paging_options: 0]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @api_true [api?: true]

  @doc """
    Function to handle GET requests to `/api/v2/internal-transactions` endpoint.
  """
  @spec internal_transactions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def internal_transactions(conn, params) do
    with true <-
           BackgroundMigrations.get_heavy_indexes_create_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished(),
         transaction_hash = transaction_hash_from_params(params),
         false <- transaction_hash == :invalid do
      paging_options = paging_options(params)
      options = options(paging_options, %{transaction_hash: transaction_hash, limit: params["limit"]})

      result =
        options
        |> InternalTransaction.fetch()
        |> split_list_by_page()

      {internal_transactions, next_page} = result

      next_page_params =
        next_page |> next_page_params(internal_transactions, delete_parameters_from_next_page_params(params))

      conn
      |> put_status(200)
      |> render(:internal_transactions, %{
        internal_transactions: internal_transactions,
        next_page_params: next_page_params
      })
    else
      _ ->
        empty_response(conn)
    end
  end

  defp empty_response(conn) do
    conn
    |> put_status(200)
    |> render(:internal_transactions, %{
      internal_transactions: [],
      next_page_params: nil
    })
  end

  defp options(paging_options, params) do
    paging_options
    |> Keyword.put(:transaction_hash, params.transaction_hash)
    |> Keyword.update(:paging_options, default_paging_options(), fn %PagingOptions{
                                                                      page_size: page_size
                                                                    } = paging_options ->
      maybe_parsed_limit = Helper.parse_integer(params["limit"])
      %PagingOptions{paging_options | page_size: min(page_size, maybe_parsed_limit && abs(maybe_parsed_limit))}
    end)
    |> Keyword.merge(@api_true)
  end

  defp transaction_hash_from_params(params) do
    with transaction_hash_string when not is_nil(transaction_hash_string) <- params["transaction_hash"],
         {:ok, transaction_hash} <- Chain.string_to_full_hash(transaction_hash_string) do
      transaction_hash
    else
      nil -> nil
      :error -> :invalid
    end
  end
end
