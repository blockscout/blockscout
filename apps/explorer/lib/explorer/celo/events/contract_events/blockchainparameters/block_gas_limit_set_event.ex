defmodule Explorer.Celo.ContractEvents.Blockchainparameters.BlockGasLimitSetEvent do
  @moduledoc """
  Struct modelling the BlockGasLimitSet event from the Blockchainparameters Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "BlockGasLimitSet",
    topic: "0x55311ae9c14427b0863f38ed97a2a5944c50d824bbf692836246512e6822c3cf"

  event_param(:limit, {:uint, 256}, :unindexed)
end
