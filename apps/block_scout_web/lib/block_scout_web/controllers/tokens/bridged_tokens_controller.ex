defmodule BlockScoutWeb.BridgedTokensController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.BridgedTokensView
  alias Explorer.Chain
  alias Phoenix.View

  def show(conn, %{"type" => "JSON", "id" => "eth"} = params) do
    show(conn, params, :eth)
  end

  def show(conn, %{"type" => "JSON", "id" => "bsc"} = params) do
    show(conn, params, :bsc)
  end

  def show(conn, %{"id" => "eth"}) do
    total_supply = Chain.total_supply()

    render(conn, "index.html",
      current_path: current_path(conn),
      total_supply: total_supply,
      chain: "Ethereum",
      chain_id: 1
    )
  end

  def show(conn, %{"id" => "bsc"}) do
    total_supply = Chain.total_supply()

    render(conn, "index.html",
      current_path: current_path(conn),
      total_supply: total_supply,
      chain: "Binance Smart Chain",
      chain_id: 56
    )
  end

  def show(conn, _params) do
    not_found(conn)
  end

  defp show(conn, params, destination) do
    full_params =
      params
      |> paging_options()

    tokens = Chain.list_top_bridged_tokens(destination, full_params)

    {tokens_page, next_page} = split_list_by_page(tokens)

    next_page_path =
      case next_page_params(next_page, tokens_page, params) do
        nil ->
          nil

        next_page_params ->
          bridged_tokens_path(
            conn,
            :show,
            destination,
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
          BridgedTokensView,
          "_tile.html",
          token: token,
          bridged_token: bridged_token,
          index: items_count + index
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

  def index(conn, %{"type" => "JSON"} = params) do
    show(conn, params, :eth)
  end

  def index(conn, _params) do
    total_supply = Chain.total_supply()

    render(conn, "index.html",
      current_path: current_path(conn),
      total_supply: total_supply,
      chain: "Ethereum"
    )
  end
end
