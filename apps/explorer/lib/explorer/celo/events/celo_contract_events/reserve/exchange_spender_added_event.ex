defmodule Explorer.Celo.ContractEvents.Reserve.ExchangeSpenderAddedEvent do
  @moduledoc """
  Struct modelling the ExchangeSpenderAdded event from the Reserve Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ExchangeSpenderAdded",
    topic: "0x71bccdb89fff4d914e3d2e472b327e3debaf4c4d6f1dfe528f430447e4cbcf5f"

  event_param(:exchange_spender, :address, :indexed)
end
