defmodule BlockScoutWeb.SmartContractView do
  use BlockScoutWeb, :view

  import Explorer.SmartContract.Reader, only: [zip_tuple_values_with_types: 2]

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Transaction}
  alias Explorer.Chain.Hash.Address, as: HashAddress
  alias Explorer.Chain.SmartContract
  alias Explorer.Chain.SmartContract.Proxy.EIP1167
  alias Explorer.SmartContract.Helper

  require Logger

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
          |> String.slice(0..-3//1)
          |> supplement_type_with_components(components)

        values =
          value
          |> tuple_array_to_array(tuple_types, fetch_name(names, index + 1))
          |> Enum.join("),\n(")

        render_array_type_value(type, "(\n" <> values <> ")", fetch_name(names, index))

      String.starts_with?(type, "address") ->
        values =
          value
          |> Enum.map_join(", ", &cast_address(&1))

        render_array_type_value(type, values, fetch_name(names, index))

      String.starts_with?(type, "bytes") ->
        values =
          value
          |> Enum.join(", ")

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

  def values_with_type(value, string, names, index, _components) when string in ["string", :string],
    do: render_type_value("string", Helper.sanitize_input(value), fetch_name(names, index))

  def values_with_type(value, "bytes" <> _ = bytes_type, names, index, _components),
    do: render_type_value(bytes_type, Helper.sanitize_input(value), fetch_name(names, index))

  def values_with_type(value, bytes, names, index, _components) when bytes in [:bytes],
    do: render_type_value("bytes", Helper.sanitize_input(value), fetch_name(names, index))

  def values_with_type(value, bool, names, index, _components) when bool in ["bool", :bool],
    do: render_type_value("bool", Helper.sanitize_input(to_string(value)), fetch_name(names, index))

  def values_with_type(value, type, names, index, _components),
    do: render_type_value(type, Helper.sanitize_input(value), fetch_name(names, index))

  def values_with_type(value, :error, _components),
    do: render_type_value("error", Helper.sanitize_input(value), "error")

  def cast_address(value) do
    case HashAddress.cast(value) do
      {:ok, address} ->
        to_string(address)

      _ ->
        Logger.warning(fn -> ["Error decoding address value: #{inspect(value)}"] end)
        "(decoding error)"
    end
  end

  defp fetch_name(nil, _index), do: nil

  defp fetch_name([], _index), do: nil

  defp fetch_name(names, index) when is_list(names) do
    Enum.at(names, index)
  end

  defp fetch_name(name, _index) when is_binary(name) do
    name
  end

  defp tuple_array_to_array(value, type, names) do
    value
    |> Enum.map(fn item ->
      tuple_to_array(item, type, names)
    end)
  end

  defp tuple_to_array(value, type, names) do
    value
    |> zip_tuple_values_with_types(type)
    |> Enum.with_index()
    |> Enum.map(fn {{type, value}, index} ->
      values_with_type(value, type, fetch_name(names, index), 0)
    end)
  end

  defp render_type_value(type, value, type) do
    "<div class=\"pl-3\"><i>(#{Helper.sanitize_input(type)})</i> : #{value}</div>"
  end

  defp render_type_value(type, value, name) do
    "<div class=\"pl-3\"><i><span style=\"color: black\">#{Helper.sanitize_input(name)}</span> (#{Helper.sanitize_input(type)})</i> : #{value}</div>"
  end

  defp render_array_type_value(type, values, name) do
    value_to_display = "[" <> values <> "]"

    render_type_value(type, value_to_display, name)
  end

  def supplement_type_with_components(type, components) do
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
    {smart_contract, _} = SmartContract.address_hash_to_smart_contract_with_bytecode_twin(to_address, options)

    Transaction.decoded_revert_reason(
      %Transaction{to_address: %{smart_contract: smart_contract}, hash: to_address},
      revert_reason,
      options
    )
  end

  def not_last_element?(length, index), do: length > 1 and index < length - 1

  def cut_rpc_url(error) do
    transport_options = Application.get_env(:explorer, :json_rpc_named_arguments)[:transport_options]

    all_urls =
      (transport_options[:urls] || []) ++
        (transport_options[:trace_urls] || []) ++
        (transport_options[:eth_call_urls] || []) ++
        (transport_options[:fallback_urls] || []) ++
        (transport_options[:fallback_trace_urls] || []) ++
        (transport_options[:fallback_eth_call_urls] || [])

    String.replace(error, Enum.reject(all_urls, &(&1 in [nil, ""])), "rpc_url")
  end
end
