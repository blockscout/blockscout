defmodule Explorer.Celo.ContractEvents.Governance.HotfixApprovedEvent do
  @moduledoc """
  Struct modelling the HotfixApproved event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "HotfixApproved",
    topic: "0x36bc158cba244a94dc9b8c08d327e8f7e3c2ab5f1925454c577527466f04851f"

  event_param(:hash, {:bytes, 32}, :indexed)
end
