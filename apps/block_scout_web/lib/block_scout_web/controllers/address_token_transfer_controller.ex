defmodule BlockScoutWeb.AddressTokenTransferController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.TransactionView
  alias Explorer.ExchangeRates.Token
  alias Explorer.{Chain, Market}
  alias Indexer.CoinBalance.OnDemandFetcher
  alias Phoenix.View

  import BlockScoutWeb.AddressController, only: [transaction_count: 1, validation_count: 1]

  import BlockScoutWeb.Chain,
    only: [next_page_params: 3, paging_options: 1, split_list_by_page: 1]

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
         {:ok, _} <- Chain.token_from_address_hash(token_hash) do
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
            current_address: address
          )
        end)

      json(conn, %{items: transfers_json, next_page_path: next_page_path})
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(
        conn,
        %{"address_id" => address_hash_string, "address_token_id" => token_hash_string}
      ) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token_hash} <- Chain.string_to_address_hash(token_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, token} <- Chain.token_from_address_hash(token_hash) do
      render(
        conn,
        "index.html",
        address: address,
        coin_balance_status: OnDemandFetcher.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        current_path: current_path(conn),
        token: token,
        transaction_count: transaction_count(address),
        validation_count: validation_count(address)
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
