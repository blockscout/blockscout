defmodule Explorer.Celo.ContractEvents.Governance.ParticipationBaselineUpdatedEvent do
  @moduledoc """
  Struct modelling the ParticipationBaselineUpdated event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ParticipationBaselineUpdated",
    topic: "0x51131d2820f04a6b6edd20e22a07d5bf847e265a3906e85256fca7d6043417c5"

  event_param(:participation_baseline, {:uint, 256}, :unindexed)
end
