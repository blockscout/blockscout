defmodule BlockScoutWeb.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{AccessHelpers, TransactionView}
  alias Explorer.Chain
  alias Phoenix.View

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
      current_path: transaction_path(conn, :index),
      transaction_estimated_count: transaction_estimated_count
    )
  end

  def show(conn, %{"id" => id}) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(id),
         :ok <- Chain.check_transaction_exists(transaction_hash) do
      if Chain.transaction_has_token_transfers?(transaction_hash) do
        redirect(conn, to: AccessHelpers.get_path(conn, :transaction_token_transfer_path, :index, id))
      else
        redirect(conn, to: AccessHelpers.get_path(conn, :transaction_internal_transaction_path, :index, id))
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
