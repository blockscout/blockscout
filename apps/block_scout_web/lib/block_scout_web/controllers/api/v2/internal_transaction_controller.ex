defmodule BlockScoutWeb.API.V2.InternalTransactionController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Explorer.{Chain, PagingOptions}

  alias Explorer.Chain.Cache.BackgroundMigrations

  import BlockScoutWeb.Chain,
    only: [
      split_list_by_page: 1,
      paging_options: 1,
      next_page_params: 3,
      fetch_internal_transactions: 1
    ]

  import Explorer.PagingOptions, only: [default_paging_options: 0]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["internal_transactions"])

  @api_true [api?: true]

  operation :internal_transactions,
    summary: "List internal transactions generated during smart contract execution",
    description:
      "Retrieves a paginated list of internal transactions. Internal transactions are generated during contract execution and not directly recorded on the blockchain.",
    parameters:
      base_params() ++
        [query_transaction_hash_param(), limit_param()] ++
        define_paging_params(["index", "block_number", "transaction_index", "items_count"]),
    responses: [
      ok:
        {"List of internal transactions with pagination information.", "application/json",
         paginated_response(
           items: Schemas.InternalTransaction,
           next_page_params_example: %{
             "index" => 50,
             "transaction_index" => 68,
             "block_number" => 22_133_247,
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

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
      options = options(paging_options, %{transaction_hash: transaction_hash, limit: params[:limit]})

      result =
        options
        |> fetch_internal_transactions()
        |> split_list_by_page()

      {internal_transactions, next_page} = result

      next_page_params =
        next_page |> next_page_params(internal_transactions, params)

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
      maybe_parsed_limit = params[:limit]
      %PagingOptions{paging_options | page_size: min(page_size, maybe_parsed_limit && abs(maybe_parsed_limit))}
    end)
    |> Keyword.merge(@api_true)
  end

  defp transaction_hash_from_params(params) do
    with transaction_hash_string when not is_nil(transaction_hash_string) <- params[:transaction_hash],
         {:ok, transaction_hash} <- Chain.string_to_full_hash(transaction_hash_string) do
      transaction_hash
    else
      nil -> nil
      :error -> :invalid
    end
  end
end
