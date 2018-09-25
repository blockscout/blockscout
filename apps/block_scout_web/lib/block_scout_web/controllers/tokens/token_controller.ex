defmodule BlockScoutWeb.Tokens.TokenController do
  use BlockScoutWeb, :controller

  def show(conn, %{"id" => address_hash_string}) do
    redirect(conn, to: token_transfer_path(conn, :index, address_hash_string))
  end
end
