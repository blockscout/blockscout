defmodule BlockScoutWeb.Tokens.InstanceController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  def show(conn, %{"id" => token_id, "token_address_hash" => token_address_hash}) do
    with {:ok, token_address} <- Chain.hash_to_address(token_address_hash, []),
         {:ok, token_transfer} <-
           Chain.erc721_token_instance_from_token_id_and_token_address(token_id, token_address.hash) do
      json(conn, token_transfer)
    else
      _ ->
        not_found(conn)
    end
  end
end
