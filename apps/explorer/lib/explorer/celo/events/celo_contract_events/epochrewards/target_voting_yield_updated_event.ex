defmodule Explorer.Celo.ContractEvents.Epochrewards.TargetVotingYieldUpdatedEvent do
  @moduledoc """
  Struct modelling the TargetVotingYieldUpdated event from the Epochrewards Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "TargetVotingYieldUpdated",
    topic: "0x49d8cdfe05bae61517c234f65f4088454013bafe561115126a8fe0074dc7700e"

  event_param(:fraction, {:uint, 256}, :unindexed)
end
