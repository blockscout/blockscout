defmodule BlockScoutWeb.TransactionInternalTransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{InternalTransactionView, TransactionView}
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View

  def index(conn, %{"transaction_id" => hash_string, "type" => "JSON"} = params) do
    with {:ok, hash} <- Chain.string_to_transaction_hash(hash_string),
         :ok <- Chain.check_transaction_exists(hash) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              [created_contract_address: :names] => :optional,
              [from_address: :names] => :optional,
              [to_address: :names] => :optional,
              [transaction: :block] => :optional
            }
          ],
          paging_options(params)
        )

      internal_transactions_plus_one = Chain.transaction_to_internal_transactions(hash, full_options)

      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_path =
        case next_page_params(next_page, internal_transactions, params) do
          nil ->
            nil

          next_page_params ->
            transaction_internal_transaction_path(
              conn,
              :index,
              hash,
              Map.delete(next_page_params, "type")
            )
        end

      items =
        internal_transactions
        |> Enum.map(fn internal_transaction ->
          View.render_to_string(
            InternalTransactionView,
            "_tile.html",
            internal_transaction: internal_transaction
          )
        end)

      json(
        conn,
        %{
          items: items,
          next_page_path: next_page_path
        }
      )
    else
      :error ->
        conn
        |> put_status(422)
        |> put_view(TransactionView)
        |> render("invalid.html", transaction_hash: hash_string)

      :not_found ->
        conn
        |> put_status(404)
        |> put_view(TransactionView)
        |> render("not_found.html", transaction_hash: hash_string)
    end
  end

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
               :token_transfers => :optional
             }
           ) do
      render(
        conn,
        "index.html",
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        current_path: current_path(conn),
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
