defmodule Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteActivatedEvent do
  @moduledoc """
  Struct modelling the Election.ValidatorGroupVoteActivated event

  ValidatorGroupVoteActivated(
      address indexed account,
      address indexed group,
      uint256 value,
      uint256 units
    );
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupVoteActivated",
    topic: "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe"

  event_param(:account, :address, :indexed)
  event_param(:group, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
  event_param(:units, {:uint, 256}, :unindexed)
end
