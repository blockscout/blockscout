defmodule Explorer.Celo.ContractEvents.Sortedoracles.MedianUpdatedEvent do
  @moduledoc """
  Struct modelling the MedianUpdated event from the Sortedoracles Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "MedianUpdated",
    topic: "0xa9981ebfc3b766a742486e898f54959b050a66006dbce1a4155c1f84a08bcf41"

  event_param(:token, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
end
