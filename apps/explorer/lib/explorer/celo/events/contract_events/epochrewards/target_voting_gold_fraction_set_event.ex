defmodule Explorer.Celo.ContractEvents.Epochrewards.TargetVotingGoldFractionSetEvent do
  @moduledoc """
  Struct modelling the TargetVotingGoldFractionSet event from the Epochrewards Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "TargetVotingGoldFractionSet",
    topic: "0xbae2f33c70949fbc7325c98655f3039e5e1c7f774874c99fd4f31ec5f432b159"

  event_param(:fraction, {:uint, 256}, :unindexed)
end
