defmodule Explorer.Celo.ContractEvents.Attestations.AttestationsRequestedEvent do
  @moduledoc """
  Struct modelling the AttestationsRequested event from the Attestations Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AttestationsRequested",
    topic: "0x381545d9b1fffcb94ffbbd0bccfff9f1fb3acd474d34f7d59112a5c9973fee49"

  event_param(:identifier, {:bytes, 32}, :indexed)
  event_param(:account, :address, :indexed)
  event_param(:attestations_requested, {:uint, 256}, :unindexed)
  event_param(:attestation_request_fee_token, :address, :unindexed)
end
