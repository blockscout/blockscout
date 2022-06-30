defmodule Explorer.Celo.ContractEvents.Attestations.AttestationsTransferredEvent do
  @moduledoc """
  Struct modelling the AttestationsTransferred event from the Attestations Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AttestationsTransferred",
    topic: "0x35bc19e2c74829d0a96c765bb41b09ce24a9d0757486ced0d075e79089323638"

  event_param(:identifier, {:bytes, 32}, :indexed)
  event_param(:from_account, :address, :indexed)
  event_param(:to_account, :address, :indexed)
end
