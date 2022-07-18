defmodule Explorer.Celo.ContractEvents.Governance.ProposalQueuedEvent do
  @moduledoc """
  Struct modelling the ProposalQueued event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ProposalQueued",
    topic: "0x1bfe527f3548d9258c2512b6689f0acfccdd0557d80a53845db25fc57e93d8fe"

  event_param(:proposal_id, {:uint, 256}, :indexed)
  event_param(:proposer, :address, :indexed)
  event_param(:transaction_count, {:uint, 256}, :unindexed)
  event_param(:deposit, {:uint, 256}, :unindexed)
  event_param(:timestamp, {:uint, 256}, :unindexed)
end
