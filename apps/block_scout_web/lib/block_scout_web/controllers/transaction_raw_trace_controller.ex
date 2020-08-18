defmodule BlockScoutWeb.TransactionRawTraceController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.TransactionView
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token

  def index(conn, %{"transaction_id" => hash_string}) do
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
               [{:to_address, :implementation_contract, :smart_contract}] => :optional,
               :token_transfers => :optional
             }
           ) do
      internal_transactions = Chain.transaction_to_internal_transactions(hash)

      render(
        conn,
        "index.html",
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        internal_transactions: internal_transactions,
        block_height: Chain.block_height(),
        show_token_transfers: Chain.transaction_has_token_transfers?(hash),
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
end
