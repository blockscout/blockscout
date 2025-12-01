defmodule BlockScoutWeb.API.V2.SearchController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import BlockScoutWeb.Chain, only: [from_param: 1, fetch_scam_token_toggle: 2]
  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens_info_to_search_results: 1]

  alias Explorer.Chain.Search
  alias Explorer.PagingOptions
  alias OpenApiSpex.Schema

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["search"])

  @api_true [api?: true]
  @min_query_length 3

  operation :search,
    summary: "Search for tokens, addresses, contracts, blocks, or transactions by identifier",
    description:
      "Performs a unified search across multiple blockchain entity types including tokens, addresses, contracts, blocks, transactions and other resources.",
    parameters:
      [q_param() | base_params()] ++
        define_search_paging_params([
          "next_page_params_type",
          "label",
          "token",
          "contract",
          "tac_operation",
          "metadata_tag",
          "block",
          "blob",
          "user_operation",
          "address",
          "ens_domain"
        ]),
    responses: [
      ok:
        {"Successful search response containing matched items and pagination information.
            Results are ordered by relevance and limited to 50 items per page.", "application/json",
         Schemas.Search.Results},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Performs a joint search for blocks, transactions, addresses and other resources.
  """
  @spec search(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def search(conn, %{q: query} = params) do
    [paging_options: paging_options] = Search.parse_paging_options(params)
    options = @api_true |> fetch_scam_token_toggle(conn)

    {search_results, next_page_params} =
      paging_options |> Search.joint_search(query, options)

    conn
    |> put_status(200)
    |> render(:search_results, %{
      search_results: search_results |> maybe_preload_ens_info_to_search_results(),
      next_page_params: next_page_params
    })
  end

  operation :check_redirect,
    summary: "Check if search query should redirect to a specific entity page",
    description: "Checks if a search query redirects to a specific entity page rather than showing search results.",
    parameters: [q_param() | base_params()],
    responses: [
      ok:
        {"Response indicating whether the query should redirect to a specific entity page.", "application/json",
         %Schema{
           type: :object,
           properties: %{
             parameter: %Schema{type: :string, nullable: true},
             redirect: %Schema{type: :boolean, nullable: true},
             type: %Schema{
               type: :string,
               enum: ["address", "block", "transaction", "user_operation", "blob"],
               nullable: true
             }
           }
         }},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Check redirect target for a query.
  """
  @spec check_redirect(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def check_redirect(conn, %{q: query}) do
    result =
      query
      |> String.trim()
      |> from_param()

    conn
    |> put_status(200)
    |> render(:search_results, %{result: result})
  end

  operation :quick_search,
    summary: "Quick (unpaginated) search",
    description: "Performs a quick, unpaginated search for short queries.",
    parameters: [q_param() | base_params()],
    responses: [
      ok:
        {"Quick search results.", "application/json",
         %Schema{type: :array, items: %Schema{type: :object}, nullable: false}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Performs a quick, unpaginated search for short queries.
  """
  @spec quick_search(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def quick_search(conn, %{q: query}) when byte_size(query) < @min_query_length do
    conn
    |> put_status(200)
    |> render(:search_results, %{search_results: []})
  end

  def quick_search(conn, %{q: query}) do
    options = @api_true |> fetch_scam_token_toggle(conn)
    search_results = Search.balanced_unpaginated_search(%PagingOptions{page_size: 50}, query, options)

    conn
    |> put_status(200)
    |> render(:search_results, %{search_results: search_results |> maybe_preload_ens_info_to_search_results()})
  end
end
