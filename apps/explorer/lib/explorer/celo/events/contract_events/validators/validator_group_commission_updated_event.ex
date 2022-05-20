defmodule Explorer.Celo.ContractEvents.Validators.ValidatorGroupCommissionUpdatedEvent do
  @moduledoc """
  Struct modelling the ValidatorGroupCommissionUpdated event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupCommissionUpdated",
    topic: "0x815d292dbc1a08dfb3103aabb6611233dd2393903e57bdf4c5b3db91198a826c"

  event_param(:group, :address, :indexed)
  event_param(:commission, {:uint, 256}, :unindexed)
end
