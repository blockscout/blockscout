defmodule BlockScoutWeb.AddressTokenBalanceController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelpers
  alias Explorer.{Chain, Market}

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with true <- ajax?(conn),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string) do
      token_balances =
        address_hash
        |> Chain.fetch_last_token_balances()
        |> Market.add_price()

      case AccessHelpers.restricted_access?(address_hash_string, params) do
        {:ok, false} ->
          conn
          |> put_status(200)
          |> put_layout(false)
          |> render("_token_balances.html", address_hash: address_hash, token_balances: token_balances)

        _ ->
          conn
          |> put_status(200)
          |> put_layout(false)
          |> render("_token_balances.html", address_hash: address_hash, token_balances: [])
      end
    else
      _ ->
        not_found(conn)
    end
  end
end
