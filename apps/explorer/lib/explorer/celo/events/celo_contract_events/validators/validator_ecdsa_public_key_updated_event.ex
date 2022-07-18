defmodule Explorer.Celo.ContractEvents.Validators.ValidatorEcdsaPublicKeyUpdatedEvent do
  @moduledoc """
  Struct modelling the ValidatorEcdsaPublicKeyUpdated event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorEcdsaPublicKeyUpdated",
    topic: "0x213377eec2c15b21fa7abcbb0cb87a67e893cdb94a2564aa4bb4d380869473c8"

  event_param(:validator, :address, :indexed)
  event_param(:ecdsa_public_key, :bytes, :unindexed)
end
