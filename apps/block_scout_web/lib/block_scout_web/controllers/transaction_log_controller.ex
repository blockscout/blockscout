defmodule BlockScoutWeb.TransactionLogController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]
  import BlockScoutWeb.Models.GetTransactionTags, only: [get_transaction_with_addresses_tags: 2]

  alias BlockScoutWeb.{AccessHelpers, Controller, TransactionController, TransactionLogView}
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View

  def index(conn, %{"transaction_id" => transaction_hash_string, "type" => "JSON"} = params) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(transaction_hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(transaction_hash,
             necessity_by_association: %{[to_address: :smart_contract] => :optional}
           ),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              [address: :names] => :optional,
              [address: :smart_contract] => :optional,
              address: :optional
            }
          ],
          paging_options(params)
        )

      logs_plus_one = Chain.transaction_to_logs(transaction_hash, full_options)

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
        unprocessable_entity(conn)

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
        current_user: current_user(conn),
        transaction: transaction,
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        from_tags: get_address_tags(transaction.from_address_hash, current_user(conn)),
        to_tags: get_address_tags(transaction.to_address_hash, current_user(conn)),
        tx_tags:
          get_transaction_with_addresses_tags(
            transaction,
            current_user(conn)
          )
      )
    else
      {:restricted_access, _} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)

      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)
    end
  end
end
