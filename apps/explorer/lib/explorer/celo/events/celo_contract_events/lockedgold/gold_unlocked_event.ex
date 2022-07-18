defmodule Explorer.Celo.ContractEvents.Lockedgold.GoldUnlockedEvent do
  @moduledoc """
  Struct modelling the GoldUnlocked event from the Lockedgold Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "GoldUnlocked",
    topic: "0xb1a3aef2a332070da206ad1868a5e327f5aa5144e00e9a7b40717c153158a588"

  event_param(:account, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
  event_param(:available, {:uint, 256}, :unindexed)
end
