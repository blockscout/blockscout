defmodule Explorer.Celo.ContractEvents.Random.RandomnessBlockRetentionWindowSetEvent do
  @moduledoc """
  Struct modelling the RandomnessBlockRetentionWindowSet event from the Random Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "RandomnessBlockRetentionWindowSet",
    topic: "0x337b24e614d34558109f3dee80fbcb3c5a4b08a6611bee45581772f64d1681e5"

  event_param(:value, {:uint, 256}, :unindexed)
end
