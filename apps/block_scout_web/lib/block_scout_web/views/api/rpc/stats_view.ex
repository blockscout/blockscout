defmodule BlockScoutWeb.API.RPC.StatsView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("tokensupply.json", token_supply) do
    RPCView.render("show.json", data: token_supply)
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end
end
