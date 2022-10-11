defmodule Explorer.Celo.ContractEvents.Lockedgold.GoldLockedEvent do
  @moduledoc """
  Struct modelling the GoldLocked event from the Lockedgold Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "GoldLocked",
    topic: "0x0f0f2fc5b4c987a49e1663ce2c2d65de12f3b701ff02b4d09461421e63e609e7"

  event_param(:account, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)

  def events_distinct_accounts do
    query = from(c in CeloContractEvent, where: c.topic == ^@topic)

    query |> distinct([gl], fragment("(?).params->'account'", gl))
  end
end
