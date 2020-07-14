defmodule BlockScoutWeb.Tokens.ReadContractController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address

  def index(conn, %{"token_id" => address_hash_string}) do
    options = [necessity_by_association: %{[contract_address: :smart_contract] => :optional}]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         :ok <- Chain.check_verified_smart_contract_exists(address_hash),
         {:ok, token} <- Chain.token_from_address_hash(address_hash, options) do
      render(
        conn,
        "index.html",
        type: :regular,
        action: :read,
        token: Market.add_price(token),
        counters_path: token_path(conn, :token_counters, %{"id" => Address.checksum(address_hash)})
      )
    else
      :not_found ->
        not_found(conn)

      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
