defmodule BlockScoutWeb.AddressTokenBalanceController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelper
  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Indexer.Fetcher.TokenBalanceOnDemand

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with true <- ajax?(conn),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string) do
      Task.start_link(fn ->
        TokenBalanceOnDemand.trigger_fetch(address_hash)
      end)

      case AccessHelper.restricted_access?(address_hash_string, params) do
        {:ok, false} ->
          conn
          |> put_status(200)
          |> put_layout(false)
          |> render("_token_balances.html",
            address_hash: Address.checksum(address_hash),
            token_balances: Chain.fetch_last_token_balances(address_hash),
            conn: conn
          )

        _ ->
          conn
          |> put_status(200)
          |> put_layout(false)
          |> render("_token_balances.html",
            address_hash: Address.checksum(address_hash),
            token_balances: [],
            conn: conn
          )
      end
    else
      _ ->
        not_found(conn)
    end
  end
end
