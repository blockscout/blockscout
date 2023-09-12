defmodule BlockScoutWeb.AddressTokenTransferController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.{AccessHelper, Controller, TransactionView}
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  import BlockScoutWeb.Chain,
    only: [current_filter: 1, next_page_params: 3, paging_options: 1, split_list_by_page: 1]

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  @transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional,
      [token_transfers: :token] => :optional,
      [token_transfers: :to_address] => :optional,
      [token_transfers: :from_address] => :optional,
      [token_transfers: :token_contract_address] => :optional,
      :block => :required
    }
  ]

  {:ok, burn_address_hash} = Chain.string_to_address_hash(burn_address_hash_string())
  @burn_address_hash burn_address_hash

  def index(
        conn,
        %{
          "address_id" => address_hash_string,
          "address_token_id" => token_hash_string,
          "type" => "JSON"
        } = params
      ) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token_hash} <- Chain.string_to_address_hash(token_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, _} <- Chain.token_from_address_hash(token_hash),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      transactions =
        Chain.address_to_transactions_with_token_transfers(
          address_hash,
          token_hash,
          paging_options(params)
        )

      {transactions_paginated, next_page} = split_list_by_page(transactions)

      next_page_path =
        case next_page_params(next_page, transactions_paginated, params) do
          nil ->
            nil

          next_page_params ->
            address_token_transfers_path(
              conn,
              :index,
              address_hash_string,
              token_hash_string,
              Map.delete(next_page_params, "type")
            )
        end

      transfers_json =
        Enum.map(transactions_paginated, fn transaction ->
          View.render_to_string(
            TransactionView,
            "_tile.html",
            conn: conn,
            transaction: transaction,
            burn_address_hash: @burn_address_hash,
            current_address: address
          )
        end)

      json(conn, %{items: transfers_json, next_page_path: next_page_path})
    else
      {:restricted_access, _} ->
        not_found(conn)

      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(
        conn,
        %{"address_id" => address_hash_string, "address_token_id" => token_hash_string} = params
      ) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token_hash} <- Chain.string_to_address_hash(token_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, token} <- Chain.token_from_address_hash(token_hash),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_coin_exchange_rate(),
        filter: params["filter"],
        current_path: Controller.current_full_path(conn),
        token: token,
        counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)}),
        tags: get_address_tags(address_hash, current_user(conn))
      )
    else
      {:restricted_access, _} ->
        not_found(conn)

      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(
        conn,
        %{
          "address_id" => address_hash_string,
          "type" => "JSON"
        } = params
      ) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      options =
        @transaction_necessity_by_association
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))

      transactions =
        Chain.address_hash_to_token_transfers(
          address_hash,
          options
        )

      {transactions_paginated, next_page} = split_list_by_page(transactions)

      next_page_path =
        case next_page_params(next_page, transactions_paginated, params) do
          nil ->
            nil

          next_page_params ->
            address_token_transfers_path(
              conn,
              :index,
              address_hash_string,
              Map.delete(next_page_params, "type")
            )
        end

      transfers_json =
        Enum.map(transactions_paginated, fn transaction ->
          View.render_to_string(
            TransactionView,
            "_tile.html",
            conn: conn,
            transaction: transaction,
            burn_address_hash: @burn_address_hash,
            current_address: address
          )
        end)

      json(conn, %{items: transfers_json, next_page_path: next_page_path})
    else
      {:restricted_access, _} ->
        not_found(conn)

      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(
        conn,
        %{"address_id" => address_hash_string} = params
      ) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_coin_exchange_rate(),
        filter: params["filter"],
        current_path: Controller.current_full_path(conn),
        counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)}),
        tags: get_address_tags(address_hash, current_user(conn))
      )
    else
      {:restricted_access, _} ->
        not_found(conn)

      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
