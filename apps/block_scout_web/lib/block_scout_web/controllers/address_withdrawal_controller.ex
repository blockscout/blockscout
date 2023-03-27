defmodule BlockScoutWeb.AddressWithdrawalController do
  @moduledoc """
    Display all the withdrawals that terminate at this Address.
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.{AccessHelper, AddressWithdrawalView, Controller}
  alias Explorer.{Chain, Market}

  alias Explorer.Chain.Wei

  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    address_options = [necessity_by_association: %{:names => :optional, :smart_contract => :optional}]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash, address_options, false),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      options =
        [necessity_by_association: %{:block => :optional}]
        |> Keyword.merge(paging_options(params))

      withdrawals_plus_one = Chain.address_hash_to_withdrawals(address_hash, options)
      {withdrawals, next_page} = split_list_by_page(withdrawals_plus_one)

      next_page_url =
        case next_page_params(next_page, withdrawals, params) do
          nil ->
            nil

          next_page_params ->
            address_withdrawal_path(
              conn,
              :index,
              address,
              Map.delete(next_page_params, "type")
            )
        end

      items_json =
        for withdrawal <- withdrawals do
          View.render_to_string(AddressWithdrawalView, "_withdrawal.html", withdrawal: withdrawal)
        end

      json(conn, %{items: items_json, next_page_path: next_page_url})
    else
      :error ->
        unprocessable_entity(conn)

      {:restricted_access, _} ->
        not_found(conn)

      {:error, :not_found} ->
        case Chain.Hash.Address.validate(address_hash_string) do
          {:ok, _} ->
            json(conn, %{items: [], next_page_path: ""})

          _ ->
            not_found(conn)
        end
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
        current_path: Controller.current_full_path(conn),
        tags: get_address_tags(address_hash, current_user(conn))
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:restricted_access, _} ->
        not_found(conn)

      {:error, :not_found} ->
        case Chain.Hash.Address.validate(address_hash_string) do
          {:ok, _} ->
            {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)

            address = %Chain.Address{
              hash: address_hash,
              smart_contract: nil,
              token: nil,
              fetched_coin_balance: %Wei{value: Decimal.new(0)}
            }

            render(
              conn,
              "index.html",
              address: address,
              coin_balance_status: nil,
              exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
              counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
              current_path: Controller.current_full_path(conn),
              tags: get_address_tags(address_hash, current_user(conn))
            )

          _ ->
            not_found(conn)
        end
    end
  end
end
