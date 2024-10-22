defmodule BlockScoutWeb.API.V2.InternalTransactionController do
  use BlockScoutWeb, :controller
  alias Explorer.Chain.InternalTransaction
  alias Explorer.{Helper, PagingOptions}

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
    paging_options = paging_options(params)

    options =
      paging_options
      |> Keyword.update(:paging_options, default_paging_options(), fn %PagingOptions{
                                                                        page_size: page_size
                                                                      } = paging_options ->
        maybe_parsed_limit = Helper.parse_integer(params["limit"])
        %PagingOptions{paging_options | page_size: min(page_size, maybe_parsed_limit && abs(maybe_parsed_limit))}
      end)
      |> Keyword.merge(@api_true)

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
  end
end
