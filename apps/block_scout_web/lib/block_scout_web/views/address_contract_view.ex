defmodule BlockScoutWeb.AddressContractView do
  use BlockScoutWeb, :view

  def format_smart_contract_abi(abi), do: Poison.encode!(abi, pretty: false)
end
