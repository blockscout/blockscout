defmodule BlockScoutWeb.SearchController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{ChainController, SearchView}
  alias Phoenix.View

  def search_results(conn, %{"q" => query, "type" => "JSON"} = params) do
    [paging_options: paging_options] = paging_options(params)
    offset = (max(paging_options.page_number, 1) - 1) * paging_options.page_size

    search_results_plus_one =
      paging_options
      |> ChainController.search_by(offset, query)

    {search_results, next_page} = split_list_by_page(search_results_plus_one)

    next_page_url =
      case next_page_params(next_page, search_results, params) do
        nil ->
          nil

        next_page_params ->
          search_path(conn, :search_results, Map.delete(next_page_params, "type"))
      end

    items =
      search_results
      |> Enum.with_index(1)
      |> Enum.map(fn {result, _index} ->
        View.render_to_string(
          SearchView,
          "_tile.html",
          result: result,
          conn: conn,
          query: query
        )
      end)

    json(
      conn,
      %{
        items: items,
        next_page_path: next_page_url
      }
    )
  end

  def search_results(conn, %{"type" => "JSON"}) do
    json(
      conn,
      %{
        items: []
      }
    )
  end

  def search_results(conn, %{"q" => query}) do
    render(
      conn,
      "results.html",
      query: query,
      current_path: search_path(conn, :search_results, q: query)
    )
  end

  def search_results(conn, %{}) do
    render(
      conn,
      "results.html",
      query: nil,
      current_path: search_path(conn, :search_results, q: nil)
    )
  end
end
