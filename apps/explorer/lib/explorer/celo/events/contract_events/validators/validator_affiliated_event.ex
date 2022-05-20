defmodule Explorer.Celo.ContractEvents.Validators.ValidatorAffiliatedEvent do
  @moduledoc """
  Struct modelling the ValidatorAffiliated event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorAffiliated",
    topic: "0x91ef92227057e201e406c3451698dd780fe7672ad74328591c88d281af31581d"

  event_param(:validator, :address, :indexed)
  event_param(:group, :address, :indexed)
end
