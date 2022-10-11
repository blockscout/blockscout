defmodule BlockScoutWeb.MakerdojoController do
  use BlockScoutWeb, :controller

  def index(conn, _params) do
    conn
    |> put_status(200)
    |> render("index.html", token: nil)
  end
end
