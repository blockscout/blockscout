defmodule Explorer.Celo.ContractEvents.Common.SpreadSetEvent do
  @moduledoc """
  Struct modelling the SpreadSet event from the Exchange, Exchangebrl, Exchangeeur, Grandamento Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "SpreadSet",
    topic: "0x8946f328efcc515b5cc3282f6cd95e87a6c0d3508421af0b52d4d3620b3e2db3"

  event_param(:spread, {:uint, 256}, :unindexed)
end
