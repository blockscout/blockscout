defmodule BlockScoutWeb.Tokens.Instance.TransferController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, Market}

  def show(conn, %{"token_id" => token_id, "id" => token_address_hash}) do
    with {:ok, hash} <- Chain.string_to_address_hash(token_address_hash),
         {:ok, token} <- Chain.token_from_address_hash(hash),
         {:ok, token_transfer} <-
           Chain.erc721_token_instance_from_token_id_and_token_address(token_id, hash) do
      render(
        conn,
        "index.html",
        token_instance: token_transfer,
        current_path: current_path(conn),
        token: Market.add_price(token),
        total_token_transfers: Chain.count_token_transfers_from_token_hash(hash)
      )
    else
      _ ->
        not_found(conn)
    end
  end

  def show(conn, _) do
    not_found(conn)
  end
end
