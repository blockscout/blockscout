defmodule BlockScoutWeb.TransactionInternalTransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.TransactionView
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token

  def index(conn, %{"transaction_id" => hash_string} = params) do
    with {:ok, hash} <- Chain.string_to_transaction_hash(hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(
             hash,
             necessity_by_association: %{
               :block => :optional,
               [created_contract_address: :names] => :optional,
               [from_address: :names] => :optional,
               [to_address: :names] => :optional,
               [to_address: :smart_contract] => :optional,
               :token_transfers => :optional
             }
           ) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              [created_contract_address: :names] => :optional,
              [from_address: :names] => :optional,
              [to_address: :names] => :optional
            }
          ],
          paging_options(params)
        )

      internal_transactions_plus_one = Chain.transaction_to_internal_transactions(transaction, full_options)

      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      max_block_number = max_block_number()

      render(
        conn,
        "index.html",
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        internal_transactions: internal_transactions,
        max_block_number: max_block_number,
        show_token_transfers: Chain.transaction_has_token_transfers?(hash),
        next_page_params: next_page_params(next_page, internal_transactions, params),
        transaction: transaction
      )
    else
      :error ->
        conn
        |> put_status(422)
        |> put_view(TransactionView)
        |> render("invalid.html", transaction_hash: hash_string)

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> put_view(TransactionView)
        |> render("not_found.html", transaction_hash: hash_string)
    end
  end

  defp max_block_number do
    case Chain.max_block_number() do
      {:ok, number} -> number
      {:error, :not_found} -> 0
    end
  end
end
