defmodule Explorer.Celo.ContractEvents.Governance.HotfixPreparedEvent do
  @moduledoc """
  Struct modelling the HotfixPrepared event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "HotfixPrepared",
    topic: "0x6f184ec313435b3307a4fe59e2293381f08419a87214464c875a2a247e8af5e0"

  event_param(:hash, {:bytes, 32}, :indexed)
  event_param(:epoch, {:uint, 256}, :indexed)
end
