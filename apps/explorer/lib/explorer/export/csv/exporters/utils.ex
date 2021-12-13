defmodule Explorer.Export.CSV.Utils do
  @moduledoc "Common helper functions for csv exporters."

  alias Explorer.Chain
  alias Explorer.Chain.Transaction

  def type(%{from_address_hash: address_hash}, address_hash), do: "OUT"

  def type(%{to_address_hash: address_hash}, address_hash), do: "IN"

  def type(_, _), do: ""

  def fee(transaction) do
    transaction
    |> Chain.fee(:wei)
    |> case do
      {:actual, value} -> value
      {:maximum, value} -> "Max of #{value}"
    end
  end

  # if currency is nil we assume celo as tx fee currency
  def fee_currency(%Transaction{gas_currency_hash: nil}), do: "CELO"

  def fee_currency(transaction) do
    transaction.gas_currency.token.symbol
  end
end
