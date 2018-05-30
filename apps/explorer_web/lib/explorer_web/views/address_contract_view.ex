defmodule ExplorerWeb.AddressContractView do
  use ExplorerWeb, :view

  alias Explorer.Chain.{Address, SmartContract}

  def smart_contract_verified?(%Address{smart_contract: nil}), do: false
  def smart_contract_verified?(%Address{smart_contract: %SmartContract{}}), do: true
end
