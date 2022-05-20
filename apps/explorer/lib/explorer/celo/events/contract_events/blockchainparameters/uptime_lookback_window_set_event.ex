defmodule Explorer.Celo.ContractEvents.Blockchainparameters.UptimeLookbackWindowSetEvent do
  @moduledoc """
  Struct modelling the UptimeLookbackWindowSet event from the Blockchainparameters Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "UptimeLookbackWindowSet",
    topic: "0x484a24d7faca8c4330aaf9ba5f131e6bd474ed6877a555511f39d16a1d71d15a"

  event_param(:window, {:uint, 256}, :unindexed)
  event_param(:activation_epoch, {:uint, 256}, :unindexed)
end
