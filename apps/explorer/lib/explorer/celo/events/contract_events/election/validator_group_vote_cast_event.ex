defmodule Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteCastEvent do
  @moduledoc """
  Struct modelling the ValidatorGroupVoteCast event from the Election Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupVoteCast",
    topic: "0xd3532f70444893db82221041edb4dc26c94593aeb364b0b14dfc77d5ee905152"

  event_param(:account, :address, :indexed)
  event_param(:group, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
end
