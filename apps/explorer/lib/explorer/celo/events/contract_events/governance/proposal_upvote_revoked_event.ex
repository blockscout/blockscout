defmodule Explorer.Celo.ContractEvents.Governance.ProposalUpvoteRevokedEvent do
  @moduledoc """
  Struct modelling the ProposalUpvoteRevoked event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ProposalUpvoteRevoked",
    topic: "0x7dc46237a819c9171a9c037ec98928e563892905c4d23373ca0f3f500f4ed114"

  event_param(:proposal_id, {:uint, 256}, :indexed)
  event_param(:account, :address, :indexed)
  event_param(:revoked_upvotes, {:uint, 256}, :unindexed)
end
