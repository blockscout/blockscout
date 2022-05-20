defmodule Explorer.Celo.ContractEvents.Gaspriceminimum.GasPriceMinimumUpdatedEvent do
  @moduledoc """
  Struct modelling the GasPriceMinimumUpdated event from the Gaspriceminimum Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "GasPriceMinimumUpdated",
    topic: "0x6e53b2f8b69496c2a175588ad1326dbabe2f66df4d82f817aeca52e3474807fb"

  event_param(:gas_price_minimum, {:uint, 256}, :unindexed)
end
