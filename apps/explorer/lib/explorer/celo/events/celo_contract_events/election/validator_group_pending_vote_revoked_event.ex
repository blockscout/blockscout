defmodule Explorer.Celo.ContractEvents.Election.ValidatorGroupPendingVoteRevokedEvent do
  @moduledoc """
  Struct modelling the ValidatorGroupPendingVoteRevoked event from the Election Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupPendingVoteRevoked",
    topic: "0x148075455e24d5cf538793db3e917a157cbadac69dd6a304186daf11b23f76fe"

  event_param(:account, :address, :indexed)
  event_param(:group, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
end
