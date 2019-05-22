defmodule Explorer.Chain.InternalTransaction.Result do
  @moduledoc """
  The result of performing the `t:EthereumJSONRPC.Parity.Action.t/0` in a `t:EthereumJSONRPC.Parity.Trace.t/0`.
  """

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias Explorer.Chain.{Data, Hash}

  def to_raw(result) when is_map(result) do
    Enum.into(result, %{}, &entry_to_raw/1)
  end

  defp entry_to_raw({"output" = key, %Data{} = data}) do
    {key, Data.to_string(data)}
  end

  defp entry_to_raw({"address" = key, %Hash{} = hash}) do
    {key, to_string(hash)}
  end

  defp entry_to_raw({"code", code}), do: {"code", Data.to_string(code)}

  defp entry_to_raw({key, decimal}) when key in ~w(gasUsed) do
    integer =
      decimal
      |> Decimal.round()
      |> Decimal.to_integer()

    {key, integer_to_quantity(integer)}
  end
end
