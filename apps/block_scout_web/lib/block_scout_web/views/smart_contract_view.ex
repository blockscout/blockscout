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
  def int?(type), do: String.contains?(type, "int") && !String.contains?(type, "[")

  def named_argument?(%{"name" => ""}), do: false
  def named_argument?(%{"name" => nil}), do: false
  def named_argument?(%{"name" => _}), do: true
  def named_argument?(_), do: false

  def values(value, type) when is_list(value) do
    if String.starts_with?(type, "tuple") do
      array_from_tuple = tuple_array_to_array(value, type)

      array_from_tuple
      |> Enum.join(",")
    else
      item_type =
        type
        |> String.split("[")
        |> Enum.at(0)

      value
      |> Enum.map(&values(&1, item_type))
      |> Enum.join(",")
    end
  end

  def values(value, type) when is_tuple(value) do
    tuple_to_array(value, type)
  end

  def values(value, type) when type in ["address", "address payable"] do
    {:ok, address} = Explorer.Chain.Hash.Address.cast(value)
    binary_to_utf_string(address)
  end

  def values(value, "string"), do: value

  def values(value, _), do: binary_to_utf_string(value)

  defp tuple_array_to_array(value, type) do
    type = type |> String.slice(0..-3)

    value
    |> Enum.map(fn item ->
      tuple_to_array(item, type)
    end)
  end

  defp tuple_to_array(value, type) do
    types_string =
      type
      |> String.slice(6..-2)
      |> String.split(",")

    {tuple_types, _} =
      types_string
      |> Enum.reduce({[], nil}, fn val, acc ->
        {arr, to_merge} = acc

        if to_merge do
          if count_string_symbols(val)["]"] > count_string_symbols(val)["["] do
            updated_arr = update_last_list_item(arr, val)
            {updated_arr, !to_merge}
          else
            updated_arr = update_last_list_item(arr, val)
            {updated_arr, to_merge}
          end
        else
          if count_string_symbols(val)["["] > count_string_symbols(val)["]"] do
            # credo:disable-for-next-line
            {arr ++ [val], !to_merge}
          else
            # credo:disable-for-next-line
            {arr ++ [val], to_merge}
          end
        end
      end)

    values_list =
      value
      |> Tuple.to_list()

    values_types_list = Enum.zip(tuple_types, values_list)

    values_types_list
    |> Enum.map(fn {type, value} ->
      values(value, type)
    end)
    |> Enum.join(",")
  end

  defp update_last_list_item(arr, new_val) do
    arr
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      if index == Enum.count(arr) - 1 do
        item <> "," <> new_val
      else
        item
      end
    end)
  end

  defp count_string_symbols(str) do
    str
    |> String.graphemes()
    |> Enum.reduce(%{"[" => 0, "]" => 0}, fn char, acc ->
      Map.update(acc, char, 1, &(&1 + 1))
    end)
  end

  defp binary_to_utf_string(item) do
    if is_binary(item), do: "0x" <> Base.encode16(item, case: :lower), else: item
  end
end
