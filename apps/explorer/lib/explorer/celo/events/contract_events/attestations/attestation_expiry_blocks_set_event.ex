defmodule Explorer.Celo.ContractEvents.Attestations.AttestationExpiryBlocksSetEvent do
  @moduledoc """
  Struct modelling the AttestationExpiryBlocksSet event from the Attestations Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AttestationExpiryBlocksSet",
    topic: "0x4fbe976a07a9260091c2d347f8780c4bc636392e34d5b249b367baf8a5c7ca69"

  event_param(:value, {:uint, 256}, :unindexed)
end
