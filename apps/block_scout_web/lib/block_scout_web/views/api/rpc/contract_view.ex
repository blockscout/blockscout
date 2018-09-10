defmodule BlockScoutWeb.API.RPC.ContractView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("getabi.json", %{abi: abi}) do
    RPCView.render("show.json", data: Jason.encode!(abi))
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end
end
