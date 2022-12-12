defmodule BlockScoutWeb.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 2,
      supplement_page_options: 2
    ]

  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]
  import BlockScoutWeb.Models.GetTransactionTags, only: [get_transaction_with_addresses_tags: 2]

  alias BlockScoutWeb.{
    AccessHelpers,
    Controller,
    TransactionInternalTransactionController,
    TransactionTokenTransferController,
    TransactionView
  }

  alias Explorer.{Chain, Market, PagingOptions}
  alias Explorer.Chain.Cache.Transaction, as: TransactionCache
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View

  @necessity_by_association %{
    :block => :optional,
    [created_contract_address: :names] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional,
    [to_address: :smart_contract] => :optional,
    :token_transfers => :optional
  }

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  @default_options [
    paging_options: %PagingOptions{page_size: Chain.default_page_size()},
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional
    }
  ]

  def index(conn, %{"type" => "JSON"} = params) do
    options =
      @default_options
      |> supplement_page_options(params)

    %{total_transactions_count: transactions_count, transactions: transactions} =
      Chain.recent_collated_transactions_for_rap(options)

    next_page_params = next_page_params(params, transactions_count)

    json(
      conn,
      %{
        items:
          Enum.map(transactions, fn transaction ->
            View.render_to_string(
              TransactionView,
              "_tile.html",
              transaction: transaction,
              burn_address_hash: @burn_address_hash,
              conn: conn
            )
          end),
        next_page_params: next_page_params
      }
    )
  end

  def index(conn, _params) do
    transaction_estimated_count = TransactionCache.estimated_count()

    render(
      conn,
      "index.html",
      current_path: Controller.current_full_path(conn),
      transaction_estimated_count: transaction_estimated_count
    )
  end

  def show(conn, %{"id" => transaction_hash_string, "type" => "JSON"}) do
    case Chain.string_to_transaction_hash(transaction_hash_string) do
      {:ok, transaction_hash} ->
        if Chain.transaction_has_token_transfers?(transaction_hash) do
          TransactionTokenTransferController.index(conn, %{
            "transaction_id" => transaction_hash_string,
            "type" => "JSON"
          })
        else
          TransactionInternalTransactionController.index(conn, %{
            "transaction_id" => transaction_hash_string,
            "type" => "JSON"
          })
        end

      :error ->
        set_not_found_view(conn, transaction_hash_string)
    end
  end

  def show(conn, %{"id" => id} = params) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(id),
         :ok <- Chain.check_transaction_exists(transaction_hash) do
      if Chain.transaction_has_token_transfers?(transaction_hash) do
        with {:ok, transaction} <-
               Chain.hash_to_transaction(
                 transaction_hash,
                 necessity_by_association: @necessity_by_association
               ),
             {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
             {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
          render(
            conn,
            "show_token_transfers.html",
            exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
            block_height: Chain.block_height(),
            current_path: Controller.current_full_path(conn),
            current_user: current_user(conn),
            show_token_transfers: true,
            transaction: transaction,
            from_tags: get_address_tags(transaction.from_address_hash, current_user(conn)),
            to_tags: get_address_tags(transaction.to_address_hash, current_user(conn)),
            tx_tags:
              get_transaction_with_addresses_tags(
                transaction,
                current_user(conn)
              )
          )
        else
          :not_found ->
            set_not_found_view(conn, id)

          :error ->
            unprocessable_entity(conn)

          {:error, :not_found} ->
            set_not_found_view(conn, id)

          {:restricted_access, _} ->
            set_not_found_view(conn, id)
        end
      else
        with {:ok, transaction} <-
               Chain.hash_to_transaction(
                 transaction_hash,
                 necessity_by_association: @necessity_by_association
               ),
             {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
             {:ok, false} <- AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
          render(
            conn,
            "show_internal_transactions.html",
            exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
            current_path: Controller.current_full_path(conn),
            current_user: current_user(conn),
            block_height: Chain.block_height(),
            show_token_transfers: Chain.transaction_has_token_transfers?(transaction_hash),
            transaction: transaction,
            from_tags: get_address_tags(transaction.from_address_hash, current_user(conn)),
            to_tags: get_address_tags(transaction.to_address_hash, current_user(conn)),
            tx_tags:
              get_transaction_with_addresses_tags(
                transaction,
                current_user(conn)
              )
          )
        else
          :not_found ->
            set_not_found_view(conn, id)

          :error ->
            unprocessable_entity(conn)

          {:error, :not_found} ->
            set_not_found_view(conn, id)

          {:restricted_access, _} ->
            set_not_found_view(conn, id)
        end
      end
    else
      :error ->
        unprocessable_entity(conn)

      :not_found ->
        set_not_found_view(conn, id)
    end
  end

  def set_not_found_view(conn, transaction_hash_string) do
    conn
    |> put_status(404)
    |> put_view(TransactionView)
    |> render("not_found.html", transaction_hash: transaction_hash_string)
  end
end
