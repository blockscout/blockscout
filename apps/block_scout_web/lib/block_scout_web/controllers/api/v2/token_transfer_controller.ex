defmodule BlockScoutWeb.API.V2.TokenTransferController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs
  alias Explorer.Chain
  alias Explorer.Chain.{TokenTransfer, Transaction}

  import BlockScoutWeb.Chain,
    only: [
      paging_options: 1,
      token_transfers_next_page_params: 3,
      fetch_scam_token_toggle: 2
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      token_transfers_types_options: 1
    ]

  import Explorer.MicroserviceInterfaces.BENS,
    only: [maybe_preload_ens_for_token_transfers: 1]

  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]

  alias Explorer.Chain.Token.Instance

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["token-transfers"])

  @api_true [api?: true]

  operation :token_transfers,
    summary: "List token transfers across all token types (ERC-20, ERC-721, ERC-1155)",
    description: "Retrieves a paginated list of token transfers across all token types (ERC-20, ERC-721, ERC-1155).",
    parameters:
      base_params() ++
        [token_type_param()] ++
        define_paging_params([
          "index",
          "block_number",
          "batch_log_index",
          "batch_block_hash",
          "batch_transaction_hash",
          "index_in_batch"
        ]),
    responses: [
      ok:
        {"List of token transfers with pagination information.", "application/json",
         paginated_response(
           items: Schemas.TokenTransfer,
           next_page_params_example: %{
             "index" => 50,
             "block_number" => 22_133_247
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/token-transfers` endpoint.
  """
  @spec token_transfers(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def token_transfers(conn, params) do
    paging_options = paging_options(params)

    options =
      paging_options
      |> Keyword.merge(token_transfers_types_options(params))
      |> Keyword.merge(@api_true)
      |> fetch_scam_token_toggle(conn)

    results =
      options
      |> TokenTransfer.fetch()
      |> Chain.flat_1155_batch_token_transfers()
      |> Chain.paginate_1155_batch_token_transfers(paging_options)

    {token_transfers, next_page_params} = token_transfers_next_page_params(results, params, options[:paging_options])

    transactions =
      token_transfers
      |> Enum.map(& &1.transaction)
      |> Enum.uniq()

    decoded_transactions = Transaction.decode_transactions(transactions, true, @api_true)

    decoded_transactions_map =
      transactions
      |> Enum.zip(decoded_transactions)
      |> Enum.into(%{}, fn {%{hash: hash}, decoded_input} -> {hash, decoded_input} end)

    conn
    |> put_status(200)
    |> render(:token_transfers, %{
      token_transfers:
        token_transfers
        |> Instance.preload_nft(@api_true)
        |> maybe_preload_ens_for_token_transfers()
        |> maybe_preload_metadata(),
      decoded_transactions_map: decoded_transactions_map,
      next_page_params: next_page_params
    })
  end
end
