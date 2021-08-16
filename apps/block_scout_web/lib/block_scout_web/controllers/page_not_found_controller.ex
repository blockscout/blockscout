defmodule BlockScoutWeb.PageNotFoundController do
  use BlockScoutWeb, :controller

  def index(conn, _params) do
    conn
    |> put_status(:not_found)
    |> render("index.html", token: nil)
  end
end
