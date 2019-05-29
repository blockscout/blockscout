defmodule BlockScoutWeb.TransactionLogController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{TransactionLogView, TransactionView}
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View

  def index(conn, %{"transaction_id" => transaction_hash_string, "type" => "JSON"} = params) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(transaction_hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(transaction_hash) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              address: :optional
            }
          ],
          paging_options(params)
        )

      logs_plus_one = Chain.transaction_to_logs(transaction, full_options)

      {logs, next_page} = split_list_by_page(logs_plus_one)

      next_page_url =
        case next_page_params(next_page, logs, params) do
          nil ->
            nil

          next_page_params ->
            transaction_log_path(conn, :index, transaction, Map.delete(next_page_params, "type"))
        end

      items =
        logs
        |> Enum.map(fn log ->
          View.render_to_string(
            TransactionLogView,
            "_logs.html",
            log: log,
            conn: conn,
            transaction: transaction
          )
        end)

      json(
        conn,
        %{
          items: items,
          next_page_path: next_page_url
        }
      )
    else
      :error ->
        conn
        |> put_status(422)
        |> put_view(TransactionView)
        |> render("invalid.html", transaction_hash: transaction_hash_string)

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> put_view(TransactionView)
        |> render("not_found.html", transaction_hash: transaction_hash_string)
    end
  end

  def index(conn, %{"transaction_id" => transaction_hash_string}) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(transaction_hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(
             transaction_hash,
             necessity_by_association: %{
               :block => :optional,
               [created_contract_address: :names] => :optional,
               [from_address: :names] => :required,
               [to_address: :names] => :optional,
               [to_address: :smart_contract] => :optional,
               :token_transfers => :optional
             }
           ) do
      render(
        conn,
        "index.html",
        block_height: Chain.block_height(),
        show_token_transfers: Chain.transaction_has_token_transfers?(transaction_hash),
        current_path: current_path(conn),
        transaction: transaction,
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
      )
    else
      :error ->
        conn
        |> put_status(422)
        |> put_view(TransactionView)
        |> render("invalid.html", transaction_hash: transaction_hash_string)

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> put_view(TransactionView)
        |> render("not_found.html", transaction_hash: transaction_hash_string)
    end
  end
end
