defmodule Explorer.Celo.ContractEvents.Governance.ProposalApprovedEvent do
  @moduledoc """
  Struct modelling the ProposalApproved event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ProposalApproved",
    topic: "0x28ec9e38ba73636ceb2f6c1574136f83bd46284a3c74734b711bf45e12f8d929"

  event_param(:proposal_id, {:uint, 256}, :indexed)
end
