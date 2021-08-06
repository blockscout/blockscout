defmodule BlockScoutWeb.SearchController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.{ChainController, SearchView}
  alias Phoenix.View

  def search_results(conn, %{"q" => query, "type" => "JSON"} = _params) do
    search_results_plus_one = ChainController.search_by(query)

    items =
      search_results_plus_one
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
        items: items
      }
    )
  end

  def search_results(conn, %{"q" => query}) do
    render(
      conn,
      "results.html",
      query: query,
      current_path: current_path(conn)
    )
  end
end
