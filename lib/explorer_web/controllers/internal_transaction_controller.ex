defmodule ExplorerWeb.InternalTransactionController do
  use ExplorerWeb, :controller

  alias Explorer.Transaction.Service, as: Transaction

  def index(conn, %{"transaction_id" => transaction_id}) do
    hash = String.downcase(transaction_id)

    internal_transactions = Transaction.internal_transactions(hash)

    render(
      conn,
      internal_transactions: internal_transactions,
      transaction_hash: hash
    )
  end
end
