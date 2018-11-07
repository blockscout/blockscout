defmodule BlockScoutWeb.AddressInternalTransactionController do
  @moduledoc """
    Manages the displaying of information about internal transactions as they relate to addresses
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.AddressController, only: [transaction_count: 1, validation_count: 1]
  import BlockScoutWeb.Chain, only: [current_filter: 1, paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.InternalTransactionView
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Hash
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      full_options =
        [
          necessity_by_association: %{
            [created_contract_address: :names] => :optional,
            [from_address: :names] => :optional,
            [to_address: :names] => :optional
          }
        ]
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))

      internal_transactions_plus_one = Chain.address_to_internal_transactions(address, full_options)
      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_url =
        case next_page_params(next_page, internal_transactions, params) do
          nil ->
            nil

          next_page_params ->
            address_internal_transaction_path(
              conn,
              :index,
              address,
              next_page_params
            )
        end

      json(
        conn,
        %{
          internal_transactions:
            Enum.map(internal_transactions, fn internal_transaction ->
              %{
                internal_transaction_html:
                  View.render_to_string(
                    InternalTransactionView,
                    "_tile.html",
                    current_address: address,
                    internal_transaction: internal_transaction
                  )
              }
            end),
          next_page_url: next_page_url
        }
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      full_options =
        [
          necessity_by_association: %{
            [created_contract_address: :names] => :optional,
            [from_address: :names] => :optional,
            [to_address: :names] => :optional
          }
        ]
        |> Keyword.merge(paging_options(%{}))
        |> Keyword.merge(current_filter(params))

      internal_transactions_plus_one = Chain.address_to_internal_transactions(address, full_options)
      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      render(
        conn,
        "index.html",
        address: address,
        next_page_params: next_page_params(next_page, internal_transactions, params),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        filter: params["filter"],
        internal_transactions: internal_transactions,
        transaction_count: transaction_count(address),
        validation_count: validation_count(address)
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
