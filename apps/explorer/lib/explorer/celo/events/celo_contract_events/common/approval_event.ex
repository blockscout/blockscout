defmodule Explorer.Celo.ContractEvents.Common.ApprovalEvent do
  @moduledoc """
  Struct modelling the Approval event from the Stabletoken, Goldtoken, Erc20, Stabletokenbrl, Stabletokeneur Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "Approval",
    topic: "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"

  event_param(:owner, :address, :indexed)
  event_param(:spender, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
end
