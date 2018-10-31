defmodule BlockScoutWeb.AddressTransactionController do
  @moduledoc """
    Display all the Transactions that terminate at this Address.
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.AddressController, only: [transaction_count: 1, validation_count: 1]
  import BlockScoutWeb.Chain, only: [current_filter: 1, paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.TransactionView
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
            :block => :required,
            [created_contract_address: :names] => :optional,
            [from_address: :names] => :optional,
            [to_address: :names] => :optional,
            :token_transfers => :optional
          }
        ]
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))

      transactions_plus_one = Chain.address_to_transactions(address, full_options)
      {transactions, next_page} = split_list_by_page(transactions_plus_one)

      next_page =
        case next_page_params(next_page, transactions, params) do
          nil ->
            nil

          next_page_params ->
            address_transaction_path(
              conn,
              :index,
              address,
              next_page_params
            )
        end

      json(
        conn,
        %{
          transactions:
            Enum.map(transactions, fn transaction ->
              %{
                transaction_hash: Hash.to_string(transaction.hash),
                transaction_html:
                  View.render_to_string(
                    TransactionView,
                    "_tile.html",
                    current_address: address,
                    transaction: transaction
                  )
              }
            end),
          next_page: next_page
        }
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      pending_options =
        [
          necessity_by_association: %{
            [created_contract_address: :names] => :optional,
            [from_address: :names] => :optional,
            [to_address: :names] => :optional,
            :token_transfers => :optional
          }
        ]
        |> Keyword.merge(paging_options(%{}))
        |> Keyword.merge(current_filter(params))

      full_options = put_in(pending_options, [:necessity_by_association, :block], :required)

      transactions_plus_one = Chain.address_to_transactions(address, full_options)
      {transactions, next_page} = split_list_by_page(transactions_plus_one)

      pending_transactions = Chain.address_to_pending_transactions(address, pending_options)

      render(
        conn,
        "index.html",
        address: address,
        next_page_params: next_page_params(next_page, transactions, params),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        filter: params["filter"],
        pending_transactions: pending_transactions,
        transactions: transactions,
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
