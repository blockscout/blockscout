defmodule BlockScoutWeb.API.RPC.ENSView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("ensaddress.json", %{address: address}) do
    RPCView.render("show.json", data: address)
  end

  def render("ensname.json", %{name: name}) do
    RPCView.render("show.json", data: name)
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end
end
