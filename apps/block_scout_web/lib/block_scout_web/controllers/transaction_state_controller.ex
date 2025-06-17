defmodule BlockScoutWeb.TransactionStateController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.{
    AccessHelper,
    Controller,
    Models.TransactionStateHelper,
    TransactionController,
    TransactionStateView
  }

  alias Explorer.{Chain, Market}
  alias Phoenix.View

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]
  import BlockScoutWeb.Models.GetTransactionTags, only: [get_transaction_with_addresses_tags: 2]
  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]
  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  {:ok, burn_address_hash} = Chain.string_to_address_hash(burn_address_hash_string())

  @burn_address_hash burn_address_hash

  def index(conn, %{"transaction_id" => transaction_hash_string, "type" => "JSON"} = params) do
    with {:ok, transaction_hash} <- Chain.string_to_full_hash(transaction_hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(transaction_hash),
         {:ok, false} <-
           AccessHelper.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <-
           AccessHelper.restricted_access?(to_string(transaction.to_address_hash), params) do
      state_changes_plus_next_page =
        transaction
        |> TransactionStateHelper.state_changes(
          params
          |> paging_options()
          |> Keyword.put(:ip, AccessHelper.conn_to_ip_string(conn))
        )

      {state_changes, next_page} = split_list_by_page(state_changes_plus_next_page)

      next_page_url =
        case next_page_params(next_page, state_changes, params) do
          nil ->
            nil

          next_page_params ->
            transaction_state_path(conn, :index, transaction, Map.delete(next_page_params, "type"))
        end

      rendered_changes =
        Enum.map(state_changes, fn state_change ->
          View.render_to_string(
            TransactionStateView,
            "_state_change.html",
            coin_or_token_transfers: state_change.coin_or_token_transfers,
            address: state_change.address,
            burn_address_hash: @burn_address_hash,
            balance_before: state_change.balance_before,
            balance_after: state_change.balance_after,
            balance_diff: state_change.balance_diff,
            token_id: state_change.token_id,
            conn: conn,
            miner: state_change.miner?
          )
        end)

      json(conn, %{
        items: rendered_changes,
        next_page_path: next_page_url
      })
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
    with {:ok, transaction_hash} <- Chain.string_to_full_hash(transaction_hash_string),
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
         {:ok, false} <-
           AccessHelper.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <-
           AccessHelper.restricted_access?(to_string(transaction.to_address_hash), params) do
      render(
        conn,
        "index.html",
        exchange_rate: Market.get_coin_exchange_rate(),
        block_height: Chain.block_height(),
        current_path: Controller.current_full_path(conn),
        show_token_transfers: Chain.transaction_has_token_transfers?(transaction_hash),
        transaction: transaction,
        from_tags: get_address_tags(transaction.from_address_hash, current_user(conn)),
        to_tags: get_address_tags(transaction.to_address_hash, current_user(conn)),
        transaction_tags:
          get_transaction_with_addresses_tags(
            transaction,
            current_user(conn)
          ),
        current_user: current_user(conn)
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)

      {:restricted_access, _} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)
    end
  end
end
