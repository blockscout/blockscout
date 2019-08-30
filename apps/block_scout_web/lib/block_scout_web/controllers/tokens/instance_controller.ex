defmodule BlockScoutWeb.Tokens.InstanceController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  def show(conn, %{"token_id" => token_id, "id" => token_address_hash}) do
    with {:ok, hash} <- Chain.string_to_address_hash(token_address_hash),
         {:ok, _token_address} <- Chain.token_from_address_hash(hash, []),
         {:ok, _token_transfer} <-
           Chain.erc721_token_instance_from_token_id_and_token_address(token_id, hash) |> IO.inspect() do
      redirect(conn, to: token_instance_transfer_path(conn, :index, token_id, token_address_hash))
    else
      _ ->
        not_found(conn)
    end
  end

  def show(conn, _) do
    not_found(conn)
  end
end
