defmodule Explorer.Celo.ContractEvents.Reserve.SpenderAddedEvent do
  @moduledoc """
  Struct modelling the SpenderAdded event from the Reserve Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "SpenderAdded",
    topic: "0x3139419c41cdd7abca84fa19dd21118cd285d3e2ce1a9444e8161ce9fa62fdcd"

  event_param(:spender, :address, :indexed)
end
