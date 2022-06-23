defmodule BlockScoutWeb.Account.Api.V1.TagsController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Models.UserFromAuth
  alias Explorer.Account.Identity
  alias Guardian.Plug

  def tags_address(conn, %{"address_hash" => _address_hash}) do
    if is_nil(Plug.current_claims(conn)) do
      uid = Plug.current_claims(conn)["sub"]

      with {:identity, [%Identity{} = _identity]} <- {:identity, UserFromAuth.find_identity(uid)} do
      else
        _ ->
          %{}
      end
    else
    end
  end

  def tags_transaction(conn, %{"transaction_hash" => _transaction_hash}) do
    _personal_tags =
      if is_nil(Plug.current_claims(conn)) do
        uid = Plug.current_claims(conn)["sub"]

        with {:identity, [%Identity{} = _identity]} <- {:identity, UserFromAuth.find_identity(uid)} do
        else
          _ ->
            %{}
        end
      else
      end
  end
end
