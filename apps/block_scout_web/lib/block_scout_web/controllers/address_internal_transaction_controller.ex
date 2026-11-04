# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.AddressInternalTransactionController do
  @moduledoc """
    Manages the displaying of information about internal transactions as they relate to addresses
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  import BlockScoutWeb.Chain,
    only: [
      current_filter: 1,
      paging_options: 1,
      address_to_internal_transactions: 2,
      internal_transactions_next_page_params_from_block: 2
    ]

  import BlockScoutWeb.LegacyPagingHelper, only: [next_page_params: 3, split_list_by_page: 1]

  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.{AccessHelper, Controller, InternalTransactionView}
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.{Address, Wei}
  alias Indexer.Fetcher.OnDemand.CoinBalance, as: CoinBalanceOnDemand
  alias Phoenix.View

  @address_fields [
    {:from_address_hash, :from_address},
    {:to_address_hash, :to_address},
    {:created_contract_address_hash, :created_contract_address}
  ]

  @address_necessity_by_association %{:names => :optional, :smart_contract => :optional}

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <-
           Chain.hash_to_address(address_hash, necessity_by_association: %{:smart_contract => :optional}),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      full_options = Keyword.merge(paging_options(params), current_filter(params))

      {internal_transactions, next_page_params} =
        address_hash
        |> address_to_internal_transactions(full_options)
        |> paginate_internal_transactions(params)

      next_page_path =
        if next_page_params,
          do: address_internal_transaction_path(conn, :index, address_hash, Map.delete(next_page_params, "type"))

      # the addresses are loaded by hash: the internal transactions fetched from the node don't have them preloaded
      internal_transactions_json =
        internal_transactions
        |> Chain.preload_address_participants(@address_fields, @address_necessity_by_association, [])
        |> Enum.map(fn internal_transaction ->
          View.render_to_string(
            InternalTransactionView,
            "_tile.html",
            current_address: address,
            internal_transaction: internal_transaction
          )
        end)

      json(conn, %{items: internal_transactions_json, next_page_path: next_page_path})
    else
      {:restricted_access, _} ->
        not_found(conn)

      {:error, :not_found} ->
        case Chain.Hash.Address.validate(address_hash_string) do
          {:ok, _} ->
            json(conn, %{items: [], next_page_path: ""})

          _ ->
            not_found(conn)
        end

      :error ->
        not_found(conn)
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = params) do
    ip = AccessHelper.conn_to_ip_string(conn)

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(ip, address),
        current_path: Controller.current_full_path(conn),
        exchange_rate: Market.get_coin_exchange_rate(),
        filter: params["filter"],
        counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
        tags: get_address_tags(address_hash, current_user(conn))
      )
    else
      {:restricted_access, _} ->
        not_found(conn)

      {:error, :not_found} ->
        {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)

        address = %Chain.Address{
          hash: address_hash,
          smart_contract: nil,
          token: nil,
          fetched_coin_balance: %Wei{value: Decimal.new(0)}
        }

        case Chain.Hash.Address.validate(address_hash_string) do
          {:ok, _} ->
            render(
              conn,
              "index.html",
              address: address,
              filter: params["filter"],
              coin_balance_status: CoinBalanceOnDemand.trigger_fetch(ip, address),
              exchange_rate: Market.get_coin_exchange_rate(),
              counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)}),
              current_path: Controller.current_full_path(conn),
              tags: get_address_tags(address_hash, current_user(conn))
            )

          _ ->
            not_found(conn)
        end

      :error ->
        not_found(conn)
    end
  end

  defp paginate_internal_transactions({:ok, internal_transactions_plus_one}, params) do
    {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)
    {internal_transactions, next_page_params(next_page, internal_transactions, params)}
  end

  # fetched from the node, and the request stopped before `next_block_number`: the next page goes on with it
  defp paginate_internal_transactions({:incomplete, internal_transactions, next_block_number}, params),
    do: {internal_transactions, internal_transactions_next_page_params_from_block(params, next_block_number)}
end
