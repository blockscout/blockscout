defmodule Explorer.Celo.ContractEvents.Lockedgold.GoldWithdrawnEvent do
  @moduledoc """
  Struct modelling the GoldWithdrawn event from the Lockedgold Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "GoldWithdrawn",
    topic: "0x292d39ba701489b7f640c83806d3eeabe0a32c9f0a61b49e95612ebad42211cd"

  event_param(:account, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
end
