defmodule ExplorerWeb.API.RPC.AddressView do
  use ExplorerWeb, :view

  alias ExplorerWeb.API.RPC.RPCView

  def render("balance.json", %{addresses: [address]}) do
    ether_balance = wei_to_ether(address.fetched_balance)
    RPCView.render("show.json", data: ether_balance)
  end

  def render("balance.json", assigns) do
    render("balancemulti.json", assigns)
  end

  def render("balancemulti.json", %{addresses: addresses}) do
    data =
      Enum.map(addresses, fn address ->
        %{
          "account" => "#{address.hash}",
          "balance" => wei_to_ether(address.fetched_balance)
        }
      end)

    RPCView.render("show.json", data: data)
  end

  def render("error.json", %{error: error}) do
    RPCView.render("error.json", error: error)
  end

  defp wei_to_ether(wei) do
    format_wei_value(wei, :ether, include_unit_label: false)
  end
end
