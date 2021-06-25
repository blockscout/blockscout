defmodule BlockScoutWeb.SmartContractView do
  use BlockScoutWeb, :view

  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.Chain.Hash.Address, as: HashAddress
  alias Explorer.SmartContract.Helper

  def queryable?(inputs) when not is_nil(inputs), do: Enum.any?(inputs)

  def queryable?(inputs) when is_nil(inputs), do: false

  def writable?(function) when not is_nil(function),
    do:
      !Helper.constructor?(function) && !Helper.event?(function) &&
        (Helper.payable?(function) || Helper.nonpayable?(function))

  def writable?(function) when is_nil(function), do: false

  def outputs?(outputs) when not is_nil(outputs), do: Enum.any?(outputs)

  def outputs?(outputs) when is_nil(outputs), do: false

  def address?(type), do: type in ["address", "address payable"]
  def int?(type), do: String.contains?(type, "int") && !String.contains?(type, "[")

  def named_argument?(%{"name" => ""}), do: false
  def named_argument?(%{"name" => nil}), do: false
  def named_argument?(%{"name" => _}), do: true
  def named_argument?(_), do: false

  def values_with_type(value, type, components \\ nil)

  def values_with_type(value, type, components) when is_list(value) do
    cond do
      String.starts_with?(type, "tuple") ->
        tuple_types =
          type
          |> String.slice(0..-3)
          |> supplement_type_with_components(components)

        values =
          value
          |> tuple_array_to_array(tuple_types)
          |> Enum.join(", ")

        render_array_type_value(type, values)

      String.starts_with?(type, "address") ->
        values =
          value
          |> Enum.map(&binary_to_utf_string(&1))
          |> Enum.join(", ")

        render_array_type_value(type, values)

      String.starts_with?(type, "bytes") ->
        values =
          value
          |> Enum.map(&binary_to_utf_string(&1))
          |> Enum.join(", ")

        render_array_type_value(type, values)

      true ->
        values =
          value
          |> Enum.join(", ")

        render_array_type_value(type, values)
    end
  end

  def values_with_type(value, type, _components) when is_tuple(value) do
    values =
      value
      |> tuple_to_array(type)
      |> Enum.join(", ")

    render_type_value(type, values)
  end

  def values_with_type(value, type, _components) when type in [:address, "address", "address payable"] do
    case HashAddress.cast(value) do
      {:ok, address} ->
        render_type_value("address", to_string(address))

      _ ->
        ""
    end
  end

  def values_with_type(value, "string", _components), do: render_type_value("string", value)

  def values_with_type(value, :string, _components), do: render_type_value("string", value)

  def values_with_type(value, :bytes, _components), do: render_type_value("bytes", value)

  def values_with_type(value, "bool", _components), do: render_type_value("bool", to_string(value))

  def values_with_type(value, :bool, _components), do: render_type_value("bool", to_string(value))

  def values_with_type(value, type, _components) do
    render_type_value(type, binary_to_utf_string(value))
  end

  def values_only(value, type, components) when is_list(value) do
    max_size = Enum.at(Tuple.to_list(Application.get_env(:block_scout_web, :max_size_to_show_array_as_is)), 0)
    is_too_long = length(value) > max_size

    cond do
      String.starts_with?(type, "tuple") ->
        tuple_types =
          type
          |> String.slice(0..-3)
          |> supplement_type_with_components(components)

        values =
          value
          |> tuple_array_to_array(tuple_types)
          |> Enum.join(", ")

        wrap_output(render_array_value(values), is_too_long)

      String.starts_with?(type, "address") ->
        values =
          value
          |> Enum.map(&binary_to_utf_string(&1))
          |> Enum.join(", ")

        wrap_output(render_array_value(values), is_too_long)

      String.starts_with?(type, "bytes") ->
        values =
          value
          |> Enum.map(&binary_to_utf_string(&1))
          |> Enum.join(", ")

        wrap_output(render_array_value(values), is_too_long)

      true ->
        values =
          value
          |> Enum.join(", ")

        wrap_output(render_array_value(values), is_too_long)
    end
  end

  def values_only(value, type, _components) when is_tuple(value) do
    values =
      value
      |> tuple_to_array(type)
      |> Enum.join(", ")

    max_size = Enum.at(Tuple.to_list(Application.get_env(:block_scout_web, :max_size_to_show_array_as_is)), 0)

    wrap_output(values, tuple_size(value) > max_size)
  end

  def values_only(value, type, _components) when type in [:address, "address", "address payable"] do
    {:ok, address} = HashAddress.cast(value)
    wrap_output(to_string(address))
  end

  def values_only(value, "string", _components), do: wrap_output(value)

  def values_only(value, :string, _components), do: wrap_output(value)

  def values_only(value, :bytes, _components), do: wrap_output(value)

  def values_only(value, "bool", _components), do: wrap_output(to_string(value))

  def values_only(value, :bool, _components), do: wrap_output(to_string(value))

  def values_only(value, _type, _components) do
    wrap_output(binary_to_utf_string(value))
  end

  def wrap_output(value, is_too_long \\ false) do
    if is_too_long do
      "<details class=\"py-2 word-break-all\"><summary>Click to view</summary>#{value}</details>"
    else
      "<div class=\"py-2 word-break-all\">#{value}</div>"
    end
  end

  defp tuple_array_to_array(value, type) do
    value
    |> Enum.map(fn item ->
      tuple_to_array(item, type)
    end)
  end

  defp tuple_to_array(value, type) do
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
      values_with_type(value, type)
    end)
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
          if String.starts_with?(item, "0x") do
            item
          else
            "0x" <> Base.encode16(item, case: :lower)
          end
        else
          to_string(item)
        end
    end
  end

  defp render_type_value(type, value) do
    "<div style=\"padding-left: 20px\">(#{type}) : #{value}</div>"
  end

  defp render_array_type_value(type, values) do
    value_to_display = "[" <> values <> "]"

    render_type_value(type, value_to_display)
  end

  defp render_array_value(values) do
    value_to_display = "[" <> values <> "]"

    value_to_display
  end

  defp supplement_type_with_components(type, components) do
    if type == "tuple" && components do
      types =
        components
        |> Enum.map(fn component ->
          Map.get(component, "type")
        end)
        |> Enum.join(",")

      "tuple[" <> types <> "]"
    else
      type
    end
  end
end
