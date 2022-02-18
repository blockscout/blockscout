defmodule Explorer.Celo.ContractEvents.Election.EpochRewardsDistributedToVotersEvent do
  @moduledoc """
  Struct modelling the Election.EpochRewardsDistributedToVoters event

  EpochRewardsDistributedToVoters(
      address indexed group,
      uint256 value
    );
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "EpochRewardsDistributedToVoters",
    topic: "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7"

  event_param(:group, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
end
