defmodule Explorer.Celo.ContractEvents.Attestations.AttestationRequestFeeSetEvent do
  @moduledoc """
  Struct modelling the AttestationRequestFeeSet event from the Attestations Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AttestationRequestFeeSet",
    topic: "0x7cf8b633f218e9f9bc2c06107bcaddcfee6b90580863768acdcfd4f05d7af394"

  event_param(:token, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
end
