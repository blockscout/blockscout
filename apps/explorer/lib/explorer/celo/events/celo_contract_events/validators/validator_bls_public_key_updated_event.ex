defmodule Explorer.Celo.ContractEvents.Validators.ValidatorBlsPublicKeyUpdatedEvent do
  @moduledoc """
  Struct modelling the ValidatorBlsPublicKeyUpdated event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorBlsPublicKeyUpdated",
    topic: "0x36a1aabe506bbe8802233cbb9aad628e91269e77077c953f9db3e02d7092ee33"

  event_param(:validator, :address, :indexed)
  event_param(:bls_public_key, :bytes, :unindexed)
end
