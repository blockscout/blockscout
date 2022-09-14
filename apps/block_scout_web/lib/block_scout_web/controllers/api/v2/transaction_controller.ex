defmodule BlockScoutWeb.API.V2.TransactionController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def transaction(conn, %{"transaction_hash" => transaction_hash_string}) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)} do
      conn
      |> put_status(200)
      |> render(:message, %{message: transaction_hash})
    end
  end
end
