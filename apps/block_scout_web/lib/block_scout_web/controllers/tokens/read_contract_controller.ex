defmodule BlockScoutWeb.Tokens.ReadContractController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelpers
  alias BlockScoutWeb.Account.AuthController
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.Tags.AddressToTag

  def index(conn, %{"token_id" => address_hash_string} = params) do
    options = [necessity_by_association: %{[contract_address: :smart_contract] => :optional}]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         :ok <- Chain.check_verified_smart_contract_exists(address_hash),
         {:ok, token} <- Chain.token_from_address_hash(address_hash, options),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      current_user = AuthController.current_user(conn)
      private_tags = AddressToTag.get_private_tags_on_address(address_hash, current_user)

      render(
        conn,
        "index.html",
        type: :regular,
        action: :read,
        token: Market.add_price(token),
        counters_path: token_path(conn, :token_counters, %{"id" => Address.checksum(address_hash)}),
        private_tags: private_tags
      )
    else
      {:restricted_access, _} ->
        not_found(conn)

      :not_found ->
        not_found(conn)

      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
