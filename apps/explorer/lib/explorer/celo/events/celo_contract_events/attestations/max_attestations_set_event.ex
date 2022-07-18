defmodule Explorer.Celo.ContractEvents.Attestations.MaxAttestationsSetEvent do
  @moduledoc """
  Struct modelling the MaxAttestationsSet event from the Attestations Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "MaxAttestationsSet",
    topic: "0xc1f217a1246a98ce04e938768309107630ed86c1e0e9f9995af28e23a9c06178"

  event_param(:value, {:uint, 256}, :unindexed)
end
