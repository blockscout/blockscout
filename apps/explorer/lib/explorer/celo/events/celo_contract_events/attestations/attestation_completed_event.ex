defmodule Explorer.Celo.ContractEvents.Attestations.AttestationCompletedEvent do
  @moduledoc """
  Struct modelling the AttestationCompleted event from the Attestations Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AttestationCompleted",
    topic: "0x414ff2c18c092697c4b8de49f515ac44f8bebc19b24553cf58ace913a6ac639d"

  event_param(:identifier, {:bytes, 32}, :indexed)
  event_param(:account, :address, :indexed)
  event_param(:issuer, :address, :indexed)
end
