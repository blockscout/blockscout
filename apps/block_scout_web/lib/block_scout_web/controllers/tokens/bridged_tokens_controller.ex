defmodule BlockScoutWeb.BridgedTokensController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{BridgedTokensView, Controller}
  alias Explorer.Chain
  alias Phoenix.View

  def show(conn, %{"type" => "JSON", "id" => "eth"} = params) do
    get_items(conn, params, :eth)
  end

  def show(conn, %{"type" => "JSON", "id" => "bsc"} = params) do
    get_items(conn, params, :bsc)
  end

  def show(conn, %{"type" => "JSON", "id" => "poa"} = params) do
    get_items(conn, params, :poa)
  end

  def show(conn, %{"id" => "eth"}) do
    render(conn, "index.html",
      current_path: Controller.current_full_path(conn),
      chain: "Ethereum",
      chain_id: 1,
      destination: :eth
    )
  end

  def show(conn, %{"id" => "bsc"}) do
    render(conn, "index.html",
      current_path: Controller.current_full_path(conn),
      chain: "Binance Smart Chain",
      chain_id: 56,
      destination: :bsc
    )
  end

  def show(conn, %{"id" => "poa"}) do
    render(conn, "index.html",
      current_path: Controller.current_full_path(conn),
      chain: "POA",
      chain_id: 99,
      destination: :poa
    )
  end

  def show(conn, _params) do
    not_found(conn)
  end

  def index(conn, %{"type" => "JSON"} = params) do
    get_items(conn, params, :eth)
  end

  def index(conn, _params) do
    render(conn, "index.html",
      current_path: Controller.current_full_path(conn),
      chain: "Ethereum",
      chain_id: 1,
      destination: :eth
    )
  end

  defp get_items(conn, params, destination) do
    filter =
      if Map.has_key?(params, "filter") do
        Map.get(params, "filter")
      else
        nil
      end

    paging_params =
      params
      |> paging_options()

    tokens = Chain.list_top_bridged_tokens(destination, filter, paging_params)

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
          destination: destination,
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
end
