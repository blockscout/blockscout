defmodule Explorer.Celo.ContractEvents.Common.StableTokenSetEvent do
  @moduledoc """
  Struct modelling the StableTokenSet event from the Exchange, Exchangebrl, Exchangeeur Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "StableTokenSet",
    topic: "0x119a23392e161a0bc5f9d5f3e2a6040c45b40d43a36973e10ea1de916f3d8a8a"

  event_param(:stable, :address, :indexed)
end
