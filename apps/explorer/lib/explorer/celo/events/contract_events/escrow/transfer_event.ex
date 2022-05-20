defmodule Explorer.Celo.ContractEvents.Escrow.TransferEvent do
  @moduledoc """
  Struct modelling the Transfer event from the Escrow Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "Transfer",
    topic: "0x0fc2463e82c3b8a7868e75b68a76a144816d772687e5b09f45c02db37eedf4f6"

  event_param(:from, :address, :indexed)
  event_param(:identifier, {:bytes, 32}, :indexed)
  event_param(:token, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
  event_param(:payment_id, :address, :unindexed)
  event_param(:min_attestations, {:uint, 256}, :unindexed)
end
