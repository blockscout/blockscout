defmodule BlockScoutWeb.API.V2.SearchController do
  use Phoenix.Controller

  import BlockScoutWeb.Chain, only: [from_param: 1, fetch_scam_token_toggle: 2]
  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens_info_to_search_results: 1]

  alias Explorer.Chain.Search
  alias Explorer.PagingOptions

  @api_true [api?: true]
  @min_query_length 3

  def search(conn, %{"q" => query} = params) do
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

  def check_redirect(conn, %{"q" => query}) do
    result =
      query
      |> String.trim()
      |> from_param()

    conn
    |> put_status(200)
    |> render(:search_results, %{result: result})
  end

  def quick_search(conn, %{"q" => query}) when byte_size(query) < @min_query_length do
    conn
    |> put_status(200)
    |> render(:search_results, %{search_results: []})
  end

  def quick_search(conn, %{"q" => query}) do
    options = @api_true |> fetch_scam_token_toggle(conn)
    search_results = Search.balanced_unpaginated_search(%PagingOptions{page_size: 50}, query, options)

    conn
    |> put_status(200)
    |> render(:search_results, %{search_results: search_results |> maybe_preload_ens_info_to_search_results()})
  end
end
