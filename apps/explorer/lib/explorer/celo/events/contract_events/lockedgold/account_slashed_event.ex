defmodule Explorer.Celo.ContractEvents.Lockedgold.AccountSlashedEvent do
  @moduledoc """
  Struct modelling the AccountSlashed event from the Lockedgold Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AccountSlashed",
    topic: "0x7abcb995a115c34a67528d58d5fc5ce02c22cb835ce1685046163f7d366d7111"

  event_param(:slashed, :address, :indexed)
  event_param(:penalty, {:uint, 256}, :unindexed)
  event_param(:reporter, :address, :indexed)
  event_param(:reward, {:uint, 256}, :unindexed)
end
