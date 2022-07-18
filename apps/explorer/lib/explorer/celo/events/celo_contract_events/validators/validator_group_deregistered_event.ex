defmodule Explorer.Celo.ContractEvents.Validators.ValidatorGroupDeregisteredEvent do
  @moduledoc """
  Struct modelling the ValidatorGroupDeregistered event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupDeregistered",
    topic: "0xae7e034b0748a10a219b46074b20977a9170bf4027b156c797093773619a8669"

  event_param(:group, :address, :indexed)
end
