defmodule BlockScoutWeb.Tokens.InstanceController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  def show(conn, %{"token_id" => token_id, "id" => token_address_hash}) do
    with {:ok, hash} <- Chain.string_to_address_hash(token_address_hash),
         {:ok, token_address} <- Chain.hash_to_address(hash, []),
         {:ok, token_transfer} <-
           Chain.erc721_token_instance_from_token_id_and_token_address(token_id, token_address.hash) do
      json(conn, token_transfer)
    else
      _ ->
        not_found(conn)
    end
  end

  def show(conn, _) do
    not_found(conn)
  end
end
