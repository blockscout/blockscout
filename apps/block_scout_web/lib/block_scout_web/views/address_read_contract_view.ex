defmodule ExplorerWeb.AddressReadContractView do
  use ExplorerWeb, :view

  import ExplorerWeb.AddressView, only: [smart_contract_verified?: 1]

  def queryable?(inputs), do: Enum.any?(inputs)

  def address?(type), do: type == "address"
end
