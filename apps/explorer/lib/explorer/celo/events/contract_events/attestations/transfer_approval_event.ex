defmodule Explorer.Celo.ContractEvents.Attestations.TransferApprovalEvent do
  @moduledoc """
  Struct modelling the TransferApproval event from the Attestations Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "TransferApproval",
    topic: "0x14d7ffb83f4265cb6fb62188eb603269555bf46efbc2923909ed7ac313d57af7"

  event_param(:approver, :address, :indexed)
  event_param(:indentifier, {:bytes, 32}, :indexed)
  event_param(:from, :address, :unindexed)
  event_param(:to, :address, :unindexed)
  event_param(:approved, :bool, :unindexed)
end
