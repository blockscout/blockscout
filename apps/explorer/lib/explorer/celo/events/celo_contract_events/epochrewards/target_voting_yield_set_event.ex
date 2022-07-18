defmodule Explorer.Celo.ContractEvents.Epochrewards.TargetVotingYieldSetEvent do
  @moduledoc """
  Struct modelling the TargetVotingYieldSet event from the Epochrewards Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "TargetVotingYieldSet",
    topic: "0x152c3fc1e1cd415804bc9ae15876b37e62d8909358b940e6f4847ca927f46637"

  event_param(:target, {:uint, 256}, :unindexed)
end
