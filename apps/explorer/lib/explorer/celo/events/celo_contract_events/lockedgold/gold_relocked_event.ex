defmodule Explorer.Celo.ContractEvents.Lockedgold.GoldRelockedEvent do
  @moduledoc """
  Struct modelling the GoldRelocked event from the Lockedgold Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "GoldRelocked",
    topic: "0xa823fc38a01c2f76d7057a79bb5c317710f26f7dbdea78634598d5519d0f7cb0"

  event_param(:account, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
end
