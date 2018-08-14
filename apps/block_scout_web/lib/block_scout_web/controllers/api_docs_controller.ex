defmodule BlockScoutWeb.APIDocsController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Etherscan

  def index(conn, _params) do
    conn
    |> assign(:documentation, Etherscan.get_documentation())
    |> render("index.html")
  end
end
