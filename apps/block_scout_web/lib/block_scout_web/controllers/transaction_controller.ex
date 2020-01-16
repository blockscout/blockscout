defmodule BlockScoutWeb.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.TransactionView
  alias Explorer.Chain
  alias Phoenix.View

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
      current_path: current_path(conn),
      transaction_estimated_count: transaction_estimated_count
    )
  end

  def show(conn, %{"id" => id}) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(id),
         :ok <- Chain.check_transaction_exists(transaction_hash) do
      if Chain.transaction_has_token_transfers?(transaction_hash) do
        redirect(conn, to: transaction_token_transfer_path(conn, :index, id))
      else
        redirect(conn, to: transaction_internal_transaction_path(conn, :index, id))
      end
    else
      :error -> conn |> put_status(422) |> render("invalid.html", transaction_hash: id)
      :not_found -> conn |> put_status(404) |> render("not_found.html", transaction_hash: id)
    end
  end
end
