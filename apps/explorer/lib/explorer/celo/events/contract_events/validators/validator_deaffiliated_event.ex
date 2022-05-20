defmodule Explorer.Celo.ContractEvents.Validators.ValidatorDeaffiliatedEvent do
  @moduledoc """
  Struct modelling the ValidatorDeaffiliated event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorDeaffiliated",
    topic: "0x71815121f0622b31a3e7270eb28acb9fd10825ff418c9a18591f617bb8a31a6c"

  event_param(:validator, :address, :indexed)
  event_param(:group, :address, :indexed)
end
