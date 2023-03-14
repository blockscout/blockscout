defmodule BlockScoutWeb.Tokens.HolderController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.{AccessHelpers, Controller}
  alias BlockScoutWeb.Tokens.HolderView
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Indexer.Fetcher.TokenTotalSupplyOnDemand
  alias Phoenix.View

  import BlockScoutWeb.Chain,
    only: [
      split_list_by_page: 1,
      paging_options: 1,
      next_page_params: 3
    ]

  def index(conn, %{"token_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token} <- Chain.token_from_address_hash(address_hash),
         token_balances <- Chain.fetch_token_holders_from_token_hash(address_hash, paging_options(params)),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      {token_balances_paginated, next_page} = split_list_by_page(token_balances)

      next_page_path =
        case next_page_params(next_page, token_balances_paginated, params) do
          nil ->
            nil

          next_page_params ->
            token_holder_path(conn, :index, address_hash, Map.delete(next_page_params, "type"))
        end

      token_balances_json =
        Enum.map(token_balances_paginated, fn token_balance ->
          View.render_to_string(HolderView, "_token_balances.html",
            address_hash: address_hash,
            token_balance: token_balance,
            token: token,
            conn: conn
          )
        end)

      json(conn, %{items: token_balances_json, next_page_path: next_page_path})
    else
      {:restricted_access, _} ->
        not_found(conn)

      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(conn, %{"token_id" => address_hash_string} = params) do
    options = [necessity_by_association: %{[contract_address: :smart_contract] => :optional}]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token} <- Chain.token_from_address_hash(address_hash, options),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        current_path: Controller.current_full_path(conn),
        token: Market.add_price(token),
        counters_path: token_path(conn, :token_counters, %{"id" => Address.checksum(address_hash)}),
        token_total_supply_status: TokenTotalSupplyOnDemand.trigger_fetch(address_hash),
        tags: get_address_tags(address_hash, current_user(conn))
      )
    else
      {:restricted_access, _} ->
        not_found(conn)

      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
