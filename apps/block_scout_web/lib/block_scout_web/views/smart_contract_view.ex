defmodule BlockScoutWeb.SmartContractView do
  use BlockScoutWeb, :view

  def queryable?(inputs), do: Enum.any?(inputs)

  def address?(type), do: type in ["address", "address payable"]

  def named_argument?(%{"name" => ""}), do: false
  def named_argument?(%{"name" => nil}), do: false
  def named_argument?(%{"name" => _}), do: true
  def named_argument?(_), do: false

  def values(addresses, type) when is_list(addresses) and type == "address[]" do
    addresses
    |> Enum.map(&values(&1, "address"))
    |> Enum.join(", ")
  end

  def values(value, type) when type in ["address", "address payable"] do
    {:ok, address} = Explorer.Chain.Hash.Address.cast(value)
    to_string(address)
  end

  def values(values, _) when is_list(values), do: Enum.join(values, ",")
  def values(value, _), do: value
end
