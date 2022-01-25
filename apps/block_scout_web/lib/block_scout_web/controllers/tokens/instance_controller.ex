defmodule BlockScoutWeb.Tokens.InstanceController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Controller
  alias Explorer.Chain

  def show(conn, %{"token_id" => token_address_hash, "id" => token_id}) do
    with {:ok, hash} <- Chain.string_to_address_hash(token_address_hash),
         :ok <- Chain.check_token_exists(hash),
         :ok <- Chain.check_erc721_token_instance_exists(token_id, hash) do
      token_instance_transfer_path =
        conn
        |> token_instance_transfer_path(:index, token_address_hash, token_id)
        |> Controller.full_path()

      redirect(conn, to: token_instance_transfer_path)
    else
      _ ->
        not_found(conn)
    end
  end

  def show(conn, _) do
    not_found(conn)
  end
end
