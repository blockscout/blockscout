defmodule Explorer.Celo.ContractEvents.Governance.ProposalVotedEvent do
  @moduledoc """
  Struct modelling the ProposalVoted event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ProposalVoted",
    topic: "0xf3709dc32cf1356da6b8a12a5be1401aeb00989556be7b16ae566e65fef7a9df"

  event_param(:proposal_id, {:uint, 256}, :indexed)
  event_param(:account, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
  event_param(:weight, {:uint, 256}, :unindexed)
end
