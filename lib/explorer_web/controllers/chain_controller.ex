defmodule ExplorerWeb.ChainController do
  use ExplorerWeb, :controller

  alias Explorer.Servers.ChainStatistics

  def show(conn, _params) do
    render(conn, "show.html", chain: ChainStatistics.fetch())
  end
end
