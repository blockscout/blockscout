defmodule BlockScoutWeb.Tokens.ReadContractController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  def index(conn, %{"token_id" => address_hash_string}) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token} <- Chain.token_from_address_hash(address_hash) do
      render(
        conn,
        "index.html",
        token: token,
        total_token_transfers: Chain.count_token_transfers_from_token_hash(address_hash),
        total_address_in_token_transfers: Chain.count_addresses_in_token_transfers_from_token_hash(address_hash)
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
