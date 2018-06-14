defmodule ExplorerWeb.TransactionLogController do
  use ExplorerWeb, :controller

  alias Explorer.{Chain, Market, PagingOptions}
  alias Explorer.ExchangeRates.Token

  @page_size 50
  @default_paging_options %PagingOptions{page_size: @page_size + 1}

  def index(conn, %{"transaction_id" => transaction_hash_string} = params) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(transaction_hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(
             transaction_hash,
             necessity_by_association: %{
               block: :optional,
               from_address: :required,
               to_address: :required
             }
           ) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              address: :optional
            }
          ],
          paging_options(params)
        )

      logs_plus_one = Chain.transaction_to_logs(transaction, full_options)

      {logs, next_page} = Enum.split(logs_plus_one, @page_size)

      render(
        conn,
        "index.html",
        logs: logs,
        max_block_number: max_block_number(),
        next_page_params: next_page_params(next_page, logs),
        transaction: transaction,
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  defp max_block_number do
    case Chain.max_block_number() do
      {:ok, number} -> number
      {:error, :not_found} -> 0
    end
  end

  defp next_page_params([], _logs), do: nil

  defp next_page_params(_, logs) do
    last = List.last(logs)
    %{index: last.index}
  end

  defp paging_options(params) do
    with %{"index" => index_string} <- params,
         {index, ""} <- Integer.parse(index_string) do
      [paging_options: %{@default_paging_options | key: {index}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end
end
