defmodule BlockScoutWeb.TokensController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{Controller, TokensView}
  alias Explorer.Chain
  alias Phoenix.View

  def index(conn, %{"type" => "JSON"} = params) do
    filter =
      if Map.has_key?(params, "filter") do
        Map.get(params, "filter")
      else
        nil
      end

    paging_params =
      params
      |> paging_options()

    tokens = Chain.list_top_tokens(filter, paging_params)

    {tokens_page, next_page} = split_list_by_page(tokens)

    next_page_path =
      case next_page_params(next_page, tokens_page, params) do
        nil ->
          nil

        next_page_params ->
          tokens_path(
            conn,
            :index,
            Map.delete(next_page_params, "type")
          )
      end

    items_count_str = Map.get(params, "items_count")

    items_count =
      if items_count_str do
        {items_count, _} = Integer.parse(items_count_str)
        items_count
      else
        0
      end

    items =
      tokens_page
      |> Enum.with_index(1)
      |> Enum.map(fn {[token, bridged_token], index} ->
        View.render_to_string(
          TokensView,
          "_tile.html",
          token: token,
          bridged_token: bridged_token,
          index: items_count + index,
          conn: conn
        )
      end)

    json(
      conn,
      %{
        items: items,
        next_page_path: next_page_path
      }
    )
  end

  def index(conn, _params) do
    render(conn, "index.html", current_path: Controller.current_full_path(conn))
  end
end
