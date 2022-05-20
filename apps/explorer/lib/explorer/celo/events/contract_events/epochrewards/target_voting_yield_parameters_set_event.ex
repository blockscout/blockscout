defmodule Explorer.Celo.ContractEvents.Epochrewards.TargetVotingYieldParametersSetEvent do
  @moduledoc """
  Struct modelling the TargetVotingYieldParametersSet event from the Epochrewards Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "TargetVotingYieldParametersSet",
    topic: "0x1b76e38f3fdd1f284ed4d47c9d50ff407748c516ff9761616ff638c233107625"

  event_param(:max, {:uint, 256}, :unindexed)
  event_param(:adjustment_factor, {:uint, 256}, :unindexed)
end
