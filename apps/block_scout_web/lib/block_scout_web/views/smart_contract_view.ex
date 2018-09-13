defmodule BlockScoutWeb.SmartContractView do
  use BlockScoutWeb, :view

  def queryable?(inputs), do: Enum.any?(inputs)

  def address?(type), do: type == "address"

  def named_argument?(%{"name" => ""}), do: false
  def named_argument?(%{"name" => nil}), do: false
  def named_argument?(%{"name" => _}), do: true
  def named_argument?(_), do: false

  def values(values) when is_list(values), do: Enum.join(values, ",")
  def values(value), do: value
end
