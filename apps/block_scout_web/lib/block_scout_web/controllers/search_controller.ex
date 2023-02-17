defmodule BlockScoutWeb.SearchController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{Controller, SearchView}
  alias Explorer.Chain
  alias Phoenix.View

  defp is_nonempty_array(%{"items" => items} = value) when is_map(value) and is_list(items) and length(items) > 0, do: true
  defp is_nonempty_array(_), do: false

  defp extract_item_from_chain_with_tx(chain_with_tx) do
    if chain_with_tx == nil do
      %{}
    else
      chain_with_tx |> Map.get("content") |> Poison.decode() |> elem(1) |> Map.get("items") |> Enum.at(0)
    end
  end

  defp check_external_chains(search_results, query) do
    if search_results != [] do
      search_results
    else
      {:ok, response} = HTTPoison.get("#{System.get_env("RUST_MULTICHAIN_SEARCH_URL")}/api/v1/search?q=" <> query, [], params: [])
      chain_with_tx = response.body |> Poison.decode() |> elem(1) |> Map.values() |> Enum.find(
                                                                                       fn x ->
                                                                                         x |> Map.get("content") |> Poison.decode() |> elem(1) |> is_nonempty_array()
                                                                                       end)
      item = chain_with_tx |> extract_item_from_chain_with_tx()
      type = item |> Map.get("type", nil)
      case type do
        "transaction" ->
          length = item |> Map.get("tx_hash") |> String.length()
          [%{type: type, tx_hash: Map.get(item, "tx_hash") |> String.slice(2, length - 2) |> String.upcase() |> Base.decode16() |> elem(1), address_hash: nil, block_hash: nil}]
        "address" ->
          length = item |> Map.get("address_hash") |> String.length()
          [%{type: type, tx_hash: nil, address_hash: Map.get(item, "address_hash") |> String.slice(2, length - 2) |> String.upcase() |> Base.decode16() |> elem(1), block_hash: nil}]
        "block" ->
          length = item |> Map.get("block_hash") |> String.length()
          [%{type: type, tx_hash: nil, address_hash: nil, block_hash: Map.get(item, "block_hash") |> String.slice(2, length - 2) |> String.upcase() |> Base.decode16() |> elem(1)}]
        _ ->
          []
      end
    end
  end

  def search_results(conn, %{"q" => query, "type" => "JSON"} = params) do
    [paging_options: paging_options] = paging_options(params)
    offset = (max(paging_options.page_number, 1) - 1) * paging_options.page_size

    search_results_plus_one =
      paging_options
      |> Chain.joint_search(offset, query)

    {search_results, next_page} = split_list_by_page(search_results_plus_one)

    next_page_url =
      case next_page_params(next_page, search_results, params) do
        nil ->
          nil

        next_page_params ->
          search_path(conn, :search_results, Map.delete(next_page_params, "type"))
      end
    search_results = search_results |> check_external_chains(query)
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
      current_path: Controller.current_full_path(conn)
    )
  end

  def search_results(conn, %{}) do
    render(
      conn,
      "results.html",
      query: nil,
      current_path: Controller.current_full_path(conn)
    )
  end
end
