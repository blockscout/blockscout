defmodule ExplorerWeb.API.RPC.AddressView do
  use ExplorerWeb, :view

  alias ExplorerWeb.API.RPC.RPCView

  def render("balance.json", %{address: address}) do
    ether_balance = format_wei_value(address.fetched_balance, :ether, include_unit_label: false)
    data = ether_balance
    RPCView.render("show.json", data: data)
  end

  def render("error.json", %{error: error}) do
    RPCView.render("error.json", error: error)
  end
end
