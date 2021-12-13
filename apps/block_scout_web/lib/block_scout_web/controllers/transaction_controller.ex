defmodule BlockScoutWeb.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{
    AccessHelpers,
    Controller,
    TransactionInternalTransactionController,
    TransactionTokenTransferController,
    TransactionView
  }

  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Explorer.Tags.AddressToTag
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

  def index(conn, %{"type" => "JSON"} = params) do
    full_options =
      Keyword.merge(
        [
          necessity_by_association: %{
            :block => :required,
            [created_contract_address: :names] => :optional,
            [from_address: :names] => :optional,
            [to_address: :names] => :optional
          }
        ],
        paging_options(params)
      )

    transactions_plus_one = Chain.recent_collated_transactions(full_options)
    {transactions, next_page} = split_list_by_page(transactions_plus_one)

    next_page_path =
      case next_page_params(next_page, transactions, params) do
        nil ->
          nil

        next_page_params ->
          transaction_path(conn, :index, Map.delete(next_page_params, "type"))
      end

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
        next_page_path: next_page_path
      }
    )
  end

  def index(conn, _params) do
    transaction_estimated_count = Chain.transaction_estimated_count()

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
          tags = AddressToTag.get_tags_on_address(transaction.to_address_hash)

          render(
            conn,
            "show_token_transfers.html",
            exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
            block_height: Chain.block_height(),
            current_path: current_path(conn),
            show_token_transfers: true,
            transaction: transaction,
            tags: tags
          )
        else
          :not_found ->
            set_not_found_view(conn, id)

          :error ->
            set_invalid_view(conn, id)

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
          tags = AddressToTag.get_tags_on_address(transaction.to_address_hash)

          render(
            conn,
            "show_internal_transactions.html",
            exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
            current_path: current_path(conn),
            block_height: Chain.block_height(),
            show_token_transfers: Chain.transaction_has_token_transfers?(transaction_hash),
            transaction: transaction,
            tags: tags
          )
        else
          :not_found ->
            set_not_found_view(conn, id)

          :error ->
            set_invalid_view(conn, id)

          {:error, :not_found} ->
            set_not_found_view(conn, id)

          {:restricted_access, _} ->
            set_not_found_view(conn, id)
        end
      end
    else
      :error ->
        set_invalid_view(conn, id)

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

  def set_invalid_view(conn, transaction_hash_string) do
    conn
    |> put_status(422)
    |> put_view(TransactionView)
    |> render("invalid.html", transaction_hash: transaction_hash_string)
  end
end
