defmodule BlockScoutWeb.PendingTransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{Controller, TransactionView}
  alias Explorer.Chain
  alias Phoenix.View

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  def index(conn, %{"type" => "JSON"} = params) do
    full_options =
      Keyword.merge(
        [
          necessity_by_association: %{
            [from_address: :names] => :optional,
            [to_address: :names] => :optional,
            [created_contract_address: :names] => :optional,
            [from_address: :smart_contract] => :optional,
            [to_address: :smart_contract] => :optional
          }
        ],
        paging_options(params)
      )

    {transactions, next_page} = get_pending_transactions_and_next_page(full_options)

    next_page_url =
      case next_page_params(next_page, transactions, params) do
        nil ->
          nil

        next_page_params ->
          pending_transaction_path(
            conn,
            :index,
            Map.delete(next_page_params, "type")
          )
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
        next_page_path: next_page_url
      }
    )
  end

  def index(conn, %{"api" => "true"} = params) do
    full_options =
      Keyword.merge(
        [
          necessity_by_association: %{
            [from_address: :names] => :optional,
            [to_address: :names] => :optional,
            [created_contract_address: :names] => :optional,
            [from_address: :smart_contract] => :optional,
            [to_address: :smart_contract] => :optional
          }
        ],
        paging_options(params)
      )

    {transactions, next_page} = get_pending_transactions_and_next_page(full_options)

    next_page_url =
      case next_page_params(next_page, transactions, params) do
        nil ->
          nil

        next_page_params ->
          pending_transaction_path(
            conn,
            :index,
            Map.delete(next_page_params, "type")
          )
      end

    json(
      conn,
      %{
        items: transactions,
        next_page_path: next_page_url
      }
    )
  end

  def index(conn, _params) do
    render(conn, "index.html", current_path: Controller.current_full_path(conn))
  end

  defp get_pending_transactions_and_next_page(options) do
    transactions_plus_one = Chain.recent_pending_transactions(options)
    split_list_by_page(transactions_plus_one)
  end
end
