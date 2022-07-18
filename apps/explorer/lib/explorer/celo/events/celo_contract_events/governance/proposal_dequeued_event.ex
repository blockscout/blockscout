defmodule Explorer.Celo.ContractEvents.Governance.ProposalDequeuedEvent do
  @moduledoc """
  Struct modelling the ProposalDequeued event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ProposalDequeued",
    topic: "0x3e069fb74dcf5fbc07740b0d40d7f7fc48e9c0ca5dc3d19eb34d2e05d74c5543"

  event_param(:proposal_id, {:uint, 256}, :indexed)
  event_param(:timestamp, {:uint, 256}, :unindexed)
end
