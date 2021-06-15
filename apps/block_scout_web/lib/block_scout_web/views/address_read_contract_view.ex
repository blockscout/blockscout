defmodule BlockScoutWeb.AddressReadContractView do
  use BlockScoutWeb, :view

  def queryable?(inputs) when not is_nil(inputs), do: Enum.any?(inputs)

  def queryable?(inputs) when is_nil(inputs), do: false

  def outputs?(outputs) when not is_nil(outputs), do: Enum.any?(outputs)

  def outputs?(outputs) when is_nil(outputs), do: false

  def address?(type), do: type == "address"
end
