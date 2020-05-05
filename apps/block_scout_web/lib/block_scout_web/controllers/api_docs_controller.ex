defmodule BlockScoutWeb.APIDocsController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Etherscan
  alias Explorer.EthRPC

  def index(conn, _params) do
    conn
    |> assign(:documentation, Etherscan.get_documentation())
    |> render("index.html")
  end

  def eth_rpc(conn, _params) do
    conn
    |> assign(:documentation, EthRPC.methods())
    |> render("eth_rpc.html")
  end
end
