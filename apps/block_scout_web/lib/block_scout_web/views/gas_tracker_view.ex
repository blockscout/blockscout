defmodule BlockScoutWeb.GasTrackerView do
  use BlockScoutWeb, :view

  alias Explorer.Chain

  def hash_to_address(address_hash) do
    with {:ok, address} <- Chain.hash_to_address(address_hash) do
      address
    end
  end

  def gas_usage_perc(gas_consumed, total_gas_in_period) do
    gas_consumed
    |> Decimal.div(total_gas_in_period)
    |> Decimal.mult(100)
    |> Decimal.round(2)
  end

  def gas_fees(gas_consumed) do
    gas_consumed
    |> Decimal.div(1_000_000_000)
  end
end
