defmodule BlockScoutWeb.AddressReadContractView do
  use BlockScoutWeb, :view

  def queryable?(inputs), do: Enum.any?(inputs)

  def address?(type), do: type == "address"
end
