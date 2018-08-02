defmodule ExplorerWeb.APIDocsController do
  use ExplorerWeb, :controller

  alias ExplorerWeb.Etherscan

  def index(conn, _params) do
    conn
    |> assign(:documentation, Etherscan.get_documentation())
    |> render("index.html")
  end
end
