defmodule BlockScoutWeb.BridgedTokensController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.BridgedTokensView
  alias Explorer.Chain
  alias Phoenix.View

  def index(conn, %{"type" => "JSON"} = params) do
    tokens =
      params
      |> paging_options()
      |> Chain.list_top_bridged_tokens()

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

    items =
      tokens_page
      |> Enum.with_index(1)
      |> Enum.map(fn {token, index} ->
        View.render_to_string(
          BridgedTokensView,
          "_tile.html",
          token: token,
          index: index
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
    total_supply = Chain.total_supply()

    render(conn, "index.html",
      current_path: current_path(conn),
      total_supply: total_supply
    )
  end
end
