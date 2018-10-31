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

  @transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      [token_transfers: :token] => :optional,
      [token_transfers: :to_address] => :optional,
      [token_transfers: :from_address] => :optional,
      [token_transfers: :token_contract_address] => :optional
    }
  ]

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      options =
        @transaction_necessity_by_association
        |> put_in([:necessity_by_association, :block], :required)
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))

      {transactions, next_page} = get_transactions_and_next_page(address, options)

      next_page_url =
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
          next_page_url: next_page_url
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
        @transaction_necessity_by_association
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))

      full_options = put_in(pending_options, [:necessity_by_association, :block], :required)

      {transactions, next_page} = get_transactions_and_next_page(address, full_options)

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

  defp get_transactions_and_next_page(address, options) do
    transactions_plus_one = Chain.address_to_transactions(address, options)
    split_list_by_page(transactions_plus_one)
  end
end
