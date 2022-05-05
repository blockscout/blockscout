defmodule BlockScoutWeb.TransactionInternalTransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]
  import GetAddressTags, only: [get_address_tags: 2]
  import GetTransactionTags, only: [get_transaction_with_addresess_tags: 2]

  alias BlockScoutWeb.{AccessHelpers, Controller, InternalTransactionView, TransactionController}
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View

  def index(conn, %{"transaction_id" => transaction_hash_string, "type" => "JSON"} = params) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(transaction_hash_string),
         :ok <- Chain.check_transaction_exists(transaction_hash),
         {:ok, transaction} <- Chain.hash_to_transaction(transaction_hash, []),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              [created_contract_address: :names] => :optional,
              [from_address: :names] => :optional,
              [to_address: :names] => :optional,
              [transaction: :block] => :optional,
              [created_contract_address: :smart_contract] => :optional,
              [from_address: :smart_contract] => :optional,
              [to_address: :smart_contract] => :optional
            }
          ],
          paging_options(params)
        )

      internal_transactions_plus_one = Chain.transaction_to_internal_transactions(transaction_hash, full_options)

      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_path =
        case next_page_params(next_page, internal_transactions, params) do
          nil ->
            nil

          next_page_params ->
            transaction_internal_transaction_path(
              conn,
              :index,
              transaction_hash,
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
      {:restricted_access, _} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)

      :error ->
        TransactionController.set_invalid_view(conn, transaction_hash_string)

      {:error, :not_found} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)

      :not_found ->
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
               [from_address: :names] => :optional,
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
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        current_path: Controller.current_full_path(conn),
        current_user: current_user(conn),
        block_height: Chain.block_height(),
        show_token_transfers: Chain.transaction_has_token_transfers?(transaction_hash),
        transaction: transaction,
        from_tags: get_address_tags(transaction.from_address_hash, current_user(conn)),
        to_tags: get_address_tags(transaction.to_address_hash, current_user(conn)),
        tx_tags:
          get_transaction_with_addresess_tags(
            transaction,
            current_user(conn)
          )
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
