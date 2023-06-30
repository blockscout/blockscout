defmodule BlockScoutWeb.API.V2.SearchController do
  use Phoenix.Controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1, from_param: 1]

  alias Explorer.Chain

  def search(conn, %{"q" => query} = params) do
    [paging_options: paging_options] = paging_options(params)
    offset = (max(paging_options.page_number, 1) - 1) * paging_options.page_size

    search_results_plus_one =
      paging_options
      |> Chain.joint_search(offset, query, api?: true)

    {search_results, next_page} = split_list_by_page(search_results_plus_one)

    next_page_params = next_page_params(next_page, search_results, params)

    conn
    |> put_status(200)
    |> render(:search_results, %{search_results: search_results, next_page_params: next_page_params})
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
end
