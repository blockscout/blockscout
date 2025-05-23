defmodule Explorer.Chain.DecodingHelper do
  @moduledoc """
  Data decoding functions
  """
  alias ABI.FunctionSelector
  alias Explorer.Chain.{Address, Hash}

  require Logger

  def value_json(type, value) do
    decoded_type = FunctionSelector.decode_type(type)

    do_value_json(decoded_type, value)
  rescue
    exception ->
      Logger.warning(fn ->
        ["Error determining value json for #{inspect(type)}: ", Exception.format(:error, exception, __STACKTRACE__)]
      end)

      nil
  end

  defp do_value_json({:bytes, _}, value) do
    do_value_json(:bytes, value)
  end

  defp do_value_json({:array, type, _}, value) do
    do_value_json({:array, type}, value)
  end

  defp do_value_json({:array, type}, value) do
    values =
      Enum.map(value, fn inner_value ->
        do_value_json(type, inner_value)
      end)

    values
  end

  defp do_value_json({:tuple, types}, values) do
    values_list =
      values
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.map(fn {value, i} ->
        do_value_json(Enum.at(types, i), value)
      end)

    values_list
  end

  defp do_value_json(type, value) do
    base_value_json(type, value)
  end

  defp base_value_json(_, {:dynamic, value}) do
    "0x" <> Base.encode16(value, case: :lower)
  end

  defp base_value_json(:address, value) do
    case Hash.Address.cast(value) do
      {:ok, address} -> Address.checksum(address)
      :error -> "0x"
    end
  end

  defp base_value_json(:bytes, value) do
    "0x" <> Base.encode16(value, case: :lower)
  end

  defp base_value_json(_, value), do: to_string(value)
end
