defmodule Explorer.Chain.InternalTransaction.Action do
  @moduledoc """
  The action that was performed in a `t:EthereumJSONRPC.Parity.Trace.t/0`
  """

  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  alias Explorer.Chain.{Data, Hash, Wei}

  def to_raw(action) when is_map(action) do
    Enum.into(action, %{}, &entry_to_raw/1)
  end

  defp entry_to_raw({key, %Data{} = data}) when key in ~w(init input) do
    {key, Data.to_string(data)}
  end

  defp entry_to_raw({key, %Hash{} = address}) when key in ~w(address from refundAddress to) do
    {key, to_string(address)}
  end

  defp entry_to_raw({"callType", type}) do
    {"callType", Atom.to_string(type)}
  end

  defp entry_to_raw({"gas" = key, %Decimal{} = decimal}) do
    value =
      decimal
      |> Decimal.round()
      |> Decimal.to_integer()

    {key, integer_to_quantity(value)}
  end

  defp entry_to_raw({key, %Wei{value: value}}) when key in ~w(balance value) do
    rounded =
      value
      |> Decimal.round()
      |> Decimal.to_integer()

    {key, integer_to_quantity(rounded)}
  end
end
