defmodule ExplorerWeb.TransactionLogController do
  use ExplorerWeb, :controller

  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token

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
      logs =
        Chain.transaction_to_logs(
          transaction,
          necessity_by_association: %{address: :optional},
          pagination: params
        )

      render(
        conn,
        "index.html",
        logs: logs,
        max_block_number: max_block_number(),
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
end
