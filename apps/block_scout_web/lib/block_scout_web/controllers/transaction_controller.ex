defmodule BlockScoutWeb.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token

  def index(conn, params) do
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

    transaction_estimated_count = Chain.transaction_estimated_count()

    render(
      conn,
      "index.html",
      next_page_params: next_page_params(next_page, transactions, params),
      transaction_estimated_count: transaction_estimated_count,
      transactions: transactions
    )
  end

  def show(conn, %{"id" => hash_string} = params) do
    with {:ok, hash} <- Chain.string_to_transaction_hash(hash_string),
         {:ok, transaction} <- Chain.hash_to_transaction(
           hash,
             necessity_by_association: %{
               :block => :optional,
               [from_address: :names] => :optional,
               [to_address: :names] => :optional,
               :token_transfers => :optional
             }
         ) do

      max_block_number = max_block_number()

      assigns = [
        max_block_number: max_block_number,
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        show_token_transfers: Chain.transaction_has_token_transfers?(hash),
        transaction: transaction
      ]

      tabs = ["token_transfers", "internal_transactions", "logs"]
      default_tab = get_default_tab(hash)
      tab = get_tab(tabs, conn.request_path, default_tab)

      render_tab(tab, conn, transaction, params, assigns)
    end
  end

  defp max_block_number do
    case Chain.max_block_number() do
      {:ok, number} -> number
      {:error, :not_found} -> 0
    end
  end

  defp get_default_tab(transaction_hash) do
    if Chain.transaction_has_token_transfers?(transaction_hash) do
      "token_transfers"
    else
      "internal_transactions"
    end
  end

  defp get_tab([], default), do: default
  defp get_tab([tab], _default), do: tab
  defp get_tab(tabs, request_path, default) do
    tabs
    |> Enum.filter(& String.match?(request_path, ~r/#{&1}/))
    |> get_tab(default)
  end

  defp render_tab("internal_transactions", conn, transaction, params, assigns) do
    internal_transactions_plus_one = Chain.transaction_to_internal_transactions(transaction, full_options("internal_transactions", params))

    {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

    internal_transaction_assigns = [
      tab: "internal_transactions",
      internal_transactions: internal_transactions,
      next_page_params: next_page_params(next_page, internal_transactions, params)
    ]

    render(conn, "show.html", assigns ++ internal_transaction_assigns)
  end

  defp render_tab("token_transfers", conn, transaction, params, assigns) do
    token_transfers_plus_one = Chain.transaction_to_token_transfers(transaction, full_options("token_transfers", params))

    {token_transfers, next_page} = split_list_by_page(token_transfers_plus_one)

    token_transfers_assigns = [
      tab: "token_transfers",
      next_page_params: next_page_params(next_page, token_transfers, params),
      token_transfers: token_transfers
    ]

    render(conn, "show.html", assigns ++ token_transfers_assigns)
  end

  defp render_tab("logs", conn, transaction, params, assigns) do
    logs_plus_one = Chain.transaction_to_logs(transaction, full_options("logs", params))

    {logs, next_page} = split_list_by_page(logs_plus_one)

    log_assigns = [
      tab: "logs",
      next_page_params: next_page_params(next_page, logs, params),
      logs: logs
    ]

    render(conn, "show.html", assigns ++ log_assigns)
  end

  defp full_options(tab, params), do: options(tab) ++ paging_options(params)

  def options("internal_transactions") do
    [
      necessity_by_association: %{
        [created_contract_address: :names] => :optional,
        [from_address: :names] => :optional,
        [to_address: :names] => :optional
      }
    ]
  end

  def options("token_transfers") do
    [
      necessity_by_association: %{
        from_address: :required,
        to_address: :required,
        token: :required
      }
    ]
  end

  def options("logs") do
    [
      necessity_by_association: %{
        address: :optional
      }
    ]
  end
end
