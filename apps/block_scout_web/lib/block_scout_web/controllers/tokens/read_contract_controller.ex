defmodule BlockScoutWeb.Tokens.ReadContractController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, Market}

  import BlockScoutWeb.Tokens.TokenController, only: [fetch_token_counters: 2]

  def index(conn, %{"token_id" => address_hash_string}) do
    options = [necessity_by_association: %{[contract_address: :smart_contract] => :optional}]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token} <- Chain.token_from_address_hash(address_hash, options) do
      {total_token_transfers, total_token_holders} = fetch_token_counters(token, address_hash)

      render(
        conn,
        "index.html",
        token: Market.add_price(token),
        total_token_transfers: total_token_transfers,
        total_token_holders: total_token_holders
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
