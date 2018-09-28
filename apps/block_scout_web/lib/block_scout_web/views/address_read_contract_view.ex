defmodule BlockScoutWeb.AddressReadContractView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.AddressView, only: [smart_contract_verified?: 1, has_internal_transactions?: 1]

  def queryable?(inputs), do: Enum.any?(inputs)

  def address?(type), do: type == "address"
end
