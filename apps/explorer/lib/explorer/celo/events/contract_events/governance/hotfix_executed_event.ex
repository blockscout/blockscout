defmodule Explorer.Celo.ContractEvents.Governance.HotfixExecutedEvent do
  @moduledoc """
  Struct modelling the HotfixExecuted event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "HotfixExecuted",
    topic: "0x708a7934acb657a77a617b1fcd5f6d7d9ad592b72934841bff01acefd10f9b63"

  event_param(:hash, {:bytes, 32}, :indexed)
end
