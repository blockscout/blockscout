defmodule BlockScoutWeb.APIDocsController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.RPC.EthController
  alias BlockScoutWeb.Etherscan

  def index(conn, _params) do
    conn
    |> assign(:documentation, Etherscan.get_documentation())
    |> render("index.html")
  end

  def eth_rpc(conn, _params) do
    conn
    |> assign(:documentation, EthController.methods())
    |> render("eth_rpc.html")
  end
end
