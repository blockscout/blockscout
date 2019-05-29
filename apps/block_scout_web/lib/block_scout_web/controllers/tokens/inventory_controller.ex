defmodule BlockScoutWeb.Tokens.InventoryController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Tokens.InventoryView
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.TokenTransfer
  alias Phoenix.View

  import BlockScoutWeb.Chain, only: [split_list_by_page: 1, default_paging_options: 0]

  def index(conn, %{"token_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token} <- Chain.token_from_address_hash(address_hash) do
      unique_tokens =
        Chain.address_to_unique_tokens(
          token.contract_address_hash,
          unique_tokens_paging_options(params)
        )

      {unique_tokens_paginated, next_page} = split_list_by_page(unique_tokens)

      next_page_path =
        case unique_tokens_next_page(next_page, unique_tokens_paginated, params) do
          nil ->
            nil

          next_page_params ->
            token_inventory_path(
              conn,
              :index,
              address_hash_string,
              Map.delete(next_page_params, "type")
            )
        end

      items =
        unique_tokens_paginated
        |> Enum.map(fn token_transfer ->
          View.render_to_string(
            InventoryView,
            "_token.html",
            token_transfer: token_transfer
          )
        end)

      json(
        conn,
        %{
          items: items,
          next_page_path: next_page_path
        }
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(conn, %{"token_id" => address_hash_string}) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token} <- Chain.token_from_address_hash(address_hash) do
      render(
        conn,
        "index.html",
        current_path: current_path(conn),
        token: Market.add_price(token),
        total_token_transfers: Chain.count_token_transfers_from_token_hash(address_hash),
        total_token_holders: token.holder_count || Chain.count_token_holders_from_token_hash(address_hash)
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  defp unique_tokens_paging_options(%{"unique_token" => token_id}),
    do: [paging_options: %{default_paging_options() | key: {token_id}}]

  defp unique_tokens_paging_options(_params), do: [paging_options: default_paging_options()]

  defp unique_tokens_next_page([], _list, _params), do: nil

  defp unique_tokens_next_page(_, list, params) do
    Map.merge(params, paging_params(List.last(list)))
  end

  defp paging_params(%TokenTransfer{token_id: token_id}) do
    %{"unique_token" => Decimal.to_integer(token_id)}
  end
end
