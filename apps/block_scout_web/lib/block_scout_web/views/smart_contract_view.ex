defmodule BlockScoutWeb.SmartContractView do
  use BlockScoutWeb, :view

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Transaction}
  alias Explorer.Chain.Hash.Address, as: HashAddress
  alias Explorer.SmartContract.Helper

  def queryable?(inputs) when not is_nil(inputs), do: Enum.any?(inputs)

  def queryable?(inputs) when is_nil(inputs), do: false

  def writable?(function) when not is_nil(function),
    do:
      !Helper.constructor?(function) && !Helper.event?(function) &&
        (Helper.payable?(function) || Helper.nonpayable?(function))

  def writable?(function) when is_nil(function), do: false

  def outputs?(outputs) when not is_nil(outputs) do
    case outputs do
      {:error, _} -> false
      _ -> Enum.any?(outputs)
    end
  end

  def outputs?(outputs) when is_nil(outputs), do: false

  def error?(outputs) when not is_nil(outputs) do
    case outputs do
      {:error, _} -> true
      _ -> false
    end
  end

  def error?(outputs) when is_nil(outputs), do: false

  def address?(type), do: type in ["address", "address payable"]
  def int?(type), do: String.contains?(type, "int") && !String.contains?(type, "[")

  def named_argument?(%{"name" => ""}), do: false
  def named_argument?(%{"name" => nil}), do: false
  def named_argument?(%{"name" => _}), do: true
  def named_argument?(_), do: false

  def values_with_type(value, type, names, index, components \\ nil)

  def values_with_type(value, type, names, index, components) when is_list(value) do
    cond do
      String.starts_with?(type, "tuple") ->
        tuple_types =
          type
          |> String.slice(0..-3)
          |> supplement_type_with_components(components)

        values =
          value
          |> tuple_array_to_array(tuple_types, fetch_name(names, index + 1))
          |> Enum.join("),\n(")

        render_array_type_value(type, "(\n" <> values <> ")", fetch_name(names, index))

      String.starts_with?(type, "address") ->
        values =
          value
          |> Enum.map_join(", ", &binary_to_utf_string(&1))

        render_array_type_value(type, values, fetch_name(names, index))

      String.starts_with?(type, "bytes") ->
        values =
          value
          |> Enum.map_join(", ", &binary_to_utf_string(&1))

        render_array_type_value(type, values, fetch_name(names, index))

      true ->
        values =
          value
          |> Enum.join("),\n(")

        render_array_type_value(type, "(\n" <> values <> ")", fetch_name(names, index))
    end
  end

  def values_with_type(value, type, names, index, _components) when is_tuple(value) do
    values =
      value
      |> tuple_to_array(type, fetch_name(names, index + 1))
      |> Enum.join("")

    render_type_value(type, values, fetch_name(names, index))
  end

  def values_with_type(value, type, names, index, _components) when type in [:address, "address", "address payable"] do
    case HashAddress.cast(value) do
      {:ok, address} ->
        render_type_value("address", to_string(address), fetch_name(names, index))

      _ ->
        ""
    end
  end

  def values_with_type(value, "string", names, index, _components),
    do: render_type_value("string", value |> Helper.sanitize_input(), fetch_name(names, index))

  def values_with_type(value, :string, names, index, _components),
    do: render_type_value("string", value |> Helper.sanitize_input(), fetch_name(names, index))

  def values_with_type(value, :bytes, names, index, _components),
    do: render_type_value("bytes", value |> Helper.sanitize_input(), fetch_name(names, index))

  def values_with_type(value, "bool", names, index, _components),
    do: render_type_value("bool", to_string(value), fetch_name(names, index))

  def values_with_type(value, :bool, names, index, _components),
    do: render_type_value("bool", to_string(value), fetch_name(names, index))

  def values_with_type(value, type, names, index, _components),
    do: render_type_value(type, binary_to_utf_string(value), fetch_name(names, index))

  def values_with_type(value, :error, _components), do: render_type_value("error", value, "error")

  defp fetch_name(nil, _index), do: nil

  defp fetch_name([], _index), do: nil

  defp fetch_name(names, index) when is_list(names) do
    Enum.at(names, index)
  end

  defp fetch_name(name, _index) when is_binary(name) do
    name
  end

  def wrap_output(value, is_too_long \\ false) do
    if is_too_long do
      "<details class=\"py-2 word-break-all\"><summary>Click to view</summary>#{value}</details>"
    else
      "<span class=\"word-break-all\" style=\"line-height: 3;\">#{value}</span>"
    end
  end

  defp tuple_array_to_array(value, type, names) do
    value
    |> Enum.map(fn item ->
      tuple_to_array(item, type, names)
    end)
  end

  defp tuple_to_array(value, type, names) do
    types_string =
      type
      |> String.slice(6..-2)

    types =
      if String.trim(types_string) == "" do
        []
      else
        types_string
        |> String.split(",")
      end

    {tuple_types, _} =
      types
      |> Enum.reduce({[], nil}, fn val, acc ->
        {arr, to_merge} = acc

        if to_merge do
          compose_array_if_to_merge(arr, val, to_merge)
        else
          compose_array_else(arr, val, to_merge)
        end
      end)

    values_list =
      value
      |> Tuple.to_list()

    values_types_list = Enum.zip(tuple_types, values_list)

    values_types_list
    |> Enum.with_index()
    |> Enum.map(fn {{type, value}, index} ->
      values_with_type(value, type, fetch_name(names, index), 0)
    end)
  end

  defp compose_array_if_to_merge(arr, val, to_merge) do
    if count_string_symbols(val)["]"] > count_string_symbols(val)["["] do
      updated_arr = update_last_list_item(arr, val)
      {updated_arr, !to_merge}
    else
      updated_arr = update_last_list_item(arr, val)
      {updated_arr, to_merge}
    end
  end

  defp compose_array_else(arr, val, to_merge) do
    if count_string_symbols(val)["["] > count_string_symbols(val)["]"] do
      # credo:disable-for-next-line
      {arr ++ [val], !to_merge}
    else
      # credo:disable-for-next-line
      {arr ++ [val], to_merge}
    end
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
    case Integer.parse(to_string(item)) do
      {item_integer, ""} ->
        to_string(item_integer)

      _ ->
        if is_binary(item) do
          add_0x(item)
        else
          to_string(item)
        end
    end
  end

  defp add_0x(item) do
    if String.starts_with?(item, "0x") do
      item
    else
      "0x" <> Base.encode16(item, case: :lower)
    end
  end

  defp render_type_value(type, value, type) do
    "<div class=\"pl-3\"><i>(#{type})</i> : #{value}</div>"
  end

  defp render_type_value(type, value, name) do
    "<div class=\"pl-3\"><i><span style=\"color: black\">#{name}</span> (#{type})</i> : #{value}</div>"
  end

  defp render_array_type_value(type, values, name) do
    value_to_display = "[" <> values <> "]"

    render_type_value(type, value_to_display, name)
  end

  defp supplement_type_with_components(type, components) do
    if type == "tuple" && components do
      types =
        components
        |> Enum.map_join(",", fn component ->
          Map.get(component, "type")
        end)

      "tuple[" <> types <> "]"
    else
      type
    end
  end

  def decode_revert_reason(to_address, revert_reason, options \\ []) do
    smart_contract = Chain.address_hash_to_smart_contract(to_address, options)

    Transaction.decoded_revert_reason(
      %Transaction{to_address: %{smart_contract: smart_contract}, hash: to_address},
      revert_reason,
      options
    )
  end

  def decode_hex_revert_reason(hex_revert_reason) do
    case Integer.parse(hex_revert_reason, 16) do
      {number, ""} ->
        :binary.encode_unsigned(number)

      _ ->
        hex_revert_reason
    end
  end

  def not_last_element?(length, index), do: length > 1 and index < length - 1
end
