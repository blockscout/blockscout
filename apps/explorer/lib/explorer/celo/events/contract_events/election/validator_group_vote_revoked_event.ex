defmodule Explorer.Celo.ContractEvents.Election.ValidatorGroupActiveVoteRevokedEvent do
  @moduledoc """
  Struct modelling the Election.ValidatorGroupActiveVoteRevoked event

  ValidatorGroupActiveVoteRevoked(
      address indexed account,
      address indexed group,
      uint256 value,
      uint256 units
    );
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupActiveVoteRevoked",
    topic: "0xae7458f8697a680da6be36406ea0b8f40164915ac9cc40c0dad05a2ff6e8c6a8"

  event_param(:account, :address, :indexed)
  event_param(:group, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
  event_param(:units, {:uint, 256}, :unindexed)
end
