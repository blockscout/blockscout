defmodule BlockScoutWeb.API.V2.TokenTransferController do
  use BlockScoutWeb, :controller
  alias BlockScoutWeb.API.V2.TokenTransferView
  alias Explorer.{Helper, PagingOptions}
  alias Explorer.Chain.{TokenTransfer, Transaction}

  import BlockScoutWeb.Chain,
    only: [
      split_list_by_page: 1,
      paging_options: 1,
      next_page_params: 3
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      delete_parameters_from_next_page_params: 1,
      token_transfers_types_options: 1
    ]

  import Explorer.PagingOptions, only: [default_paging_options: 0]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @api_true [api?: true]

  @doc """
    Function to handle GET requests to `/api/v2/token-transfers` endpoint.
  """
  @spec token_transfers(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def token_transfers(conn, params) do
    options =
      params
      |> paging_options()
      |> Keyword.update(:paging_options, default_paging_options(), fn %PagingOptions{
                                                                        page_size: page_size
                                                                      } = paging_options ->
        mb_parsed_limit = Helper.parse_integer(params["limit"])
        %PagingOptions{paging_options | page_size: min(page_size, mb_parsed_limit && abs(mb_parsed_limit))}
      end)
      |> Keyword.merge(token_transfers_types_options(params))
      |> Keyword.merge(@api_true)

    {token_transfers, next_page} = options |> TokenTransfer.fetch() |> split_list_by_page()

    transactions =
      token_transfers
      |> Enum.map(fn token_transfer ->
        token_transfer.transaction
      end)
      |> Enum.uniq()

    {decoded_transactions, _, _} = Transaction.decode_transactions(transactions, true, @api_true)

    decoded_transactions_map =
      transactions
      |> Enum.zip(decoded_transactions)
      |> Enum.into(%{}, fn {%{hash: hash}, decoded_input} -> {hash, decoded_input} end)

    next_page_params = next_page |> next_page_params(token_transfers, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> put_view(TokenTransferView)
    |> render(:token_transfers, %{
      token_transfers: token_transfers,
      decoded_transactions_map: decoded_transactions_map,
      next_page_params: next_page_params
    })
  end
end
