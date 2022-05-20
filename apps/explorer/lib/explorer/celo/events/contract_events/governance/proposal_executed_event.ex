defmodule Explorer.Celo.ContractEvents.Governance.ProposalExecutedEvent do
  @moduledoc """
  Struct modelling the ProposalExecuted event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ProposalExecuted",
    topic: "0x712ae1383f79ac853f8d882153778e0260ef8f03b504e2866e0593e04d2b291f"

  event_param(:proposal_id, {:uint, 256}, :indexed)
end
