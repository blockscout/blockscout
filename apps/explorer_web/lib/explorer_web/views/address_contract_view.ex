defmodule ExplorerWeb.AddressContractView do
  use ExplorerWeb, :view

  import ExplorerWeb.AddressView, only: [smart_contract_verified?: 1]

  def format_smart_contract_abi(abi), do: Poison.encode!(abi, pretty: true)

  def format_optimization(true), do: gettext("true")
  def format_optimization(false), do: gettext("false")
end
