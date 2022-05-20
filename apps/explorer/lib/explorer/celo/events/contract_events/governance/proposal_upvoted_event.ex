defmodule Explorer.Celo.ContractEvents.Governance.ProposalUpvotedEvent do
  @moduledoc """
  Struct modelling the ProposalUpvoted event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ProposalUpvoted",
    topic: "0xd19965d25ef670a1e322fbf05475924b7b12d81fd6b96ab718b261782efb3d62"

  event_param(:proposal_id, {:uint, 256}, :indexed)
  event_param(:account, :address, :indexed)
  event_param(:upvotes, {:uint, 256}, :unindexed)
end
