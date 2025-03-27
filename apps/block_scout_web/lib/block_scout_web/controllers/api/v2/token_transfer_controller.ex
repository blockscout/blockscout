defmodule BlockScoutWeb.API.V2.TokenTransferController do
  use BlockScoutWeb, :controller
  alias Explorer.{Chain, Helper, PagingOptions}
  alias Explorer.Chain.{TokenTransfer, Transaction}

  import BlockScoutWeb.Chain,
    only: [
      split_list_by_page: 1,
      paging_options: 1,
      token_transfers_next_page_params: 3,
      fetch_scam_token_toggle: 2
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      delete_parameters_from_next_page_params: 1,
      token_transfers_types_options: 1
    ]

  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1]
  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]
  import Explorer.PagingOptions, only: [default_paging_options: 0]

  alias Explorer.Chain.Token.Instance

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @api_true [api?: true]

  @doc """
    Function to handle GET requests to `/api/v2/token-transfers` endpoint.
  """
  @spec token_transfers(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def token_transfers(conn, params) do
    paging_options = paging_options(params)

    options =
      paging_options
      |> Keyword.update(:paging_options, default_paging_options(), fn %PagingOptions{
                                                                        page_size: page_size
                                                                      } = paging_options ->
        maybe_parsed_limit = Helper.parse_integer(params["limit"])
        %PagingOptions{paging_options | page_size: min(page_size, maybe_parsed_limit && abs(maybe_parsed_limit))}
      end)
      |> Keyword.merge(token_transfers_types_options(params))
      |> Keyword.merge(@api_true)
      |> fetch_scam_token_toggle(conn)

    result =
      options
      |> TokenTransfer.fetch()
      |> Chain.flat_1155_batch_token_transfers()
      |> Chain.paginate_1155_batch_token_transfers(paging_options)
      |> split_list_by_page()

    {token_transfers, next_page} = result

    transactions =
      token_transfers
      |> Enum.map(& &1.transaction)
      # Celo's Epoch logs does not have an associated transaction and linked to
      # the block instead, so we discard these token transfers for transaction
      # decoding
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    decoded_transactions = Transaction.decode_transactions(transactions, true, @api_true)

    decoded_transactions_map =
      transactions
      |> Enum.zip(decoded_transactions)
      |> Enum.into(%{}, fn {%{hash: hash}, decoded_input} -> {hash, decoded_input} end)

    next_page_params =
      next_page |> token_transfers_next_page_params(token_transfers, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> render(:token_transfers, %{
      token_transfers:
        token_transfers |> Instance.preload_nft(@api_true) |> maybe_preload_ens() |> maybe_preload_metadata(),
      decoded_transactions_map: decoded_transactions_map,
      next_page_params: next_page_params
    })
  end
end
