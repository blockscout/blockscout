defmodule BlockScoutWeb.Tokens.Instance.MetadataController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Tokens.Instance.Helper
  alias Explorer.Chain
  alias Explorer.Chain.Token.Instance

  def index(conn, %{"token_id" => token_address_hash, "instance_id" => token_id_string}) do
    options = [necessity_by_association: %{[contract_address: :smart_contract] => :optional}]

    with {:ok, hash} <- Chain.string_to_address_hash(token_address_hash),
         {:ok, token} <- Chain.token_from_address_hash(hash, options),
         false <- Chain.erc_20_token?(token),
         {token_id, ""} <- Integer.parse(token_id_string),
         {:ok, token_instance} <-
           Instance.nft_instance_by_token_id_and_token_address(token_id, hash) do
      if token_instance.metadata do
        Helper.render(conn, token_instance, hash, token_id, token)
      else
        not_found(conn)
      end
    else
      _ ->
        not_found(conn)
    end
  end

  def index(conn, _) do
    not_found(conn)
  end
end
