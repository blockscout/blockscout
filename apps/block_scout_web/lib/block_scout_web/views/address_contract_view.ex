defmodule BlockScoutWeb.AddressContractView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.AddressView, only: [smart_contract_verified?: 1, smart_contract_with_read_only_functions?: 1]

  def format_smart_contract_abi(abi), do: Poison.encode!(abi, pretty: false)

  def format_optimization(true), do: gettext("true")
  def format_optimization(false), do: gettext("false")
end
