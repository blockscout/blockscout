defmodule Explorer.Celo.ContractEvents.Validators.ValidatorRegisteredEvent do
  @moduledoc """
  Struct modelling the ValidatorRegistered event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorRegistered",
    topic: "0xd09501348473474a20c772c79c653e1fd7e8b437e418fe235d277d2c88853251"

  event_param(:validator, :address, :indexed)
end
