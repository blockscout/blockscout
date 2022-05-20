defmodule Explorer.Celo.ContractEvents.Validators.ValidatorDeregisteredEvent do
  @moduledoc """
  Struct modelling the ValidatorDeregistered event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorDeregistered",
    topic: "0x51407fafe7ef9bec39c65a12a4885a274190991bf1e9057fcc384fc77ff1a7f0"

  event_param(:validator, :address, :indexed)
end
