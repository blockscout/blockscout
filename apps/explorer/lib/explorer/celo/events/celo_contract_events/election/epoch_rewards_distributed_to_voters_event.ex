defmodule Explorer.Celo.ContractEvents.Election.EpochRewardsDistributedToVotersEvent do
  @moduledoc """
  Struct modelling the Election.EpochRewardsDistributedToVoters event

  EpochRewardsDistributedToVoters(
      address indexed group,
      uint256 value
    );
  """

  alias Explorer.Celo.ContractEvents.EventMap
  alias Explorer.Repo

  use Explorer.Celo.ContractEvents.Base,
    name: "EpochRewardsDistributedToVoters",
    topic: "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7"

  event_param(:group, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)

  def elected_groups_for_block(block_number) do
    events =
      query()
      |> where([e], e.block_number == ^block_number)
      |> order_by([e], asc: e.log_index)
      |> Repo.all()
      |> EventMap.celo_contract_event_to_concrete_event()

    events |> Enum.map(& &1.group)
  end
end
