defmodule BlockScoutWeb.AddressTokenBalanceController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Token.BalanceReader

  def index(conn, %{"address_id" => address_hash_string}) do
    with true <- ajax?(conn),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string) do
      token_balances =
        address_hash
        |> Chain.fetch_tokens_from_address_hash()
        |> BalanceReader.fetch_token_balances_without_error(address_hash_string)

      conn
      |> put_status(200)
      |> put_layout(false)
      |> render("_token_balances.html", tokens: token_balances)
    else
      _ ->
        not_found(conn)
    end
  end
end
