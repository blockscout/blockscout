defmodule BlockScoutWeb.TransactionTokenTransferController do
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
              from_address: :required,
              to_address: :required,
              token: :required
            }
          ],
          paging_options(params)
        )

      token_transfers_plus_one = Chain.transaction_to_token_transfers(transaction, full_options)

      {token_transfers, next_page} = split_list_by_page(token_transfers_plus_one)

      max_block_number = max_block_number()

      render(
        conn,
        "index.html",
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        max_block_number: max_block_number,
        next_page_params: next_page_params(next_page, token_transfers, params),
        token_transfers: token_transfers,
        show_token_transfers: true,
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
    case Chain.consensus_block_number(:max) do
      {:ok, number} -> number
      {:error, :not_found} -> 0
    end
  end
end
