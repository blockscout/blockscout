defmodule BlockScoutWeb.PageNotFoundController do
  use BlockScoutWeb, :controller

  def index(conn, _params) do
    conn
    |> render("index.html")
  end
end
