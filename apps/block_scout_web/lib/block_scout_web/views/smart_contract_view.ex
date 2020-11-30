defmodule BlockScoutWeb.SmartContractView do
  use BlockScoutWeb, :view

  alias Explorer.Chain

  def queryable?(inputs) when not is_nil(inputs), do: Enum.any?(inputs)

  def queryable?(inputs) when is_nil(inputs), do: false

  def writable?(function) when not is_nil(function),
    do:
      !constructor?(function) && !event?(function) &&
        (payable?(function) || nonpayable?(function))

  def writable?(function) when is_nil(function), do: false

  def outputs?(outputs) when not is_nil(outputs), do: Enum.any?(outputs)

  def outputs?(outputs) when is_nil(outputs), do: false

  defp event?(function), do: function["type"] == "event"

  defp constructor?(function), do: function["type"] == "constructor"

  def payable?(function), do: function["stateMutability"] == "payable" || function["payable"]

  def nonpayable?(function) do
    if function["type"] do
      function["stateMutability"] == "nonpayable" ||
        (!function["payable"] && !function["constant"] && !function["stateMutability"])
    else
      false
    end
  end

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

  def values(values, type) when is_list(values) and type == "tuple[]" do
    array_from_tuple = tupple_to_array(values)

    array_from_tuple_final =
      if Enum.count(array_from_tuple) > 0 do
        [result] = array_from_tuple
        result
      else
        array_from_tuple
      end

    array_from_tuple_final
  end

  def values(value, type) when type in ["address", "address payable"] do
    {:ok, address} = Explorer.Chain.Hash.Address.cast(value)
    to_string(address)
  end

  def values(values, _) when is_list(values), do: Enum.join(values, ",")
  def values(value, _), do: value

  defp tupple_to_array(values) do
    values
    |> Enum.map(fn value ->
      value
      |> Tuple.to_list()
      |> Enum.map(&binary_to_utf_string(&1))
      |> Enum.join(",")
    end)
  end

  defp binary_to_utf_string(item) do
    if is_binary(item), do: "0x" <> Base.encode16(item, case: :lower), else: item
  end
end
