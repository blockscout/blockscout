defmodule BlockScoutWeb.TransactionLogController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{AccessHelpers, Controller, TransactionController, TransactionLogView}
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View

  def index(conn, %{"transaction_id" => transaction_hash_string, "type" => "JSON"} = params) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(transaction_hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(transaction_hash,
             necessity_by_association: %{
               [to_address: :smart_contract] => :optional,
               [{:to_address, :implementation_contract, :smart_contract}] => :optional
             }
           ),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              address: :optional
            }
          ],
          paging_options(params)
        )

      from_api = false
      logs_plus_one = Chain.transaction_to_logs(transaction_hash, from_api, full_options)

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
      {:restricted_access, _} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)

      :error ->
        TransactionController.set_invalid_view(conn, transaction_hash_string)

      {:error, :not_found} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)
    end
  end

  def index(conn, %{"transaction_id" => transaction_hash_string} = params) do
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
               [{:to_address, :implementation_contract, :smart_contract}] => :optional,
               :token_transfers => :optional
             }
           ),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
      render(
        conn,
        "index.html",
        block_height: Chain.block_height(),
        show_token_transfers: Chain.transaction_has_token_transfers?(transaction_hash),
        current_path: Controller.current_full_path(conn),
        transaction: transaction,
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
      )
    else
      {:restricted_access, _} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)

      :error ->
        TransactionController.set_invalid_view(conn, transaction_hash_string)

      {:error, :not_found} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)
    end
  end
end
