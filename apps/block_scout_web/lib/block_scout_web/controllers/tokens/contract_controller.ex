defmodule BlockScoutWeb.Tokens.ContractController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.{AccessHelper, TabHelper}
  alias Explorer.Chain
  alias Explorer.Chain.Address

  def index(conn, %{"token_id" => address_hash_string} = params) do
    options = [necessity_by_association: %{[contract_address: :smart_contract] => :optional}]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         :ok <- Chain.check_verified_smart_contract_exists(address_hash),
         {:ok, token} <- Chain.token_from_address_hash(address_hash, options),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      %{type: type, action: action} =
        cond do
          TabHelper.tab_active?("read-contract", conn.request_path) ->
            %{type: :regular, action: :read}

          TabHelper.tab_active?("write-contract", conn.request_path) ->
            %{type: :regular, action: :write}

          TabHelper.tab_active?("read-proxy", conn.request_path) ->
            %{type: :proxy, action: :read}

          TabHelper.tab_active?("write-proxy", conn.request_path) ->
            %{type: :proxy, action: :write}
        end

      render(
        conn,
        "index.html",
        type: type,
        action: action,
        token: token,
        counters_path: token_path(conn, :token_counters, %{"id" => Address.checksum(address_hash)}),
        tags: get_address_tags(address_hash, current_user(conn))
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
