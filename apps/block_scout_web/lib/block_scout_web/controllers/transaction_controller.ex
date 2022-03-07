defmodule BlockScoutWeb.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 2,
      supplement_page_options: 2
    ]

  alias BlockScoutWeb.{AccessHelpers, Controller, TransactionView}
  alias Explorer.{Chain, PagingOptions}
  alias Phoenix.View

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  @default_options [
    paging_options: %PagingOptions{page_size: Chain.default_page_size()},
    necessity_by_association: %{
      :block => :required,
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
    transaction_estimated_count = Chain.transaction_estimated_count()

    render(
      conn,
      "index.html",
      current_path: Controller.current_full_path(conn),
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
