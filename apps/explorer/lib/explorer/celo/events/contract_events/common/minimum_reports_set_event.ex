defmodule Explorer.Celo.ContractEvents.Common.MinimumReportsSetEvent do
  @moduledoc """
  Struct modelling the MinimumReportsSet event from the Exchange, Exchangebrl, Exchangeeur Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "MinimumReportsSet",
    topic: "0x08523596abc266fb46d9c40ddf78fdfd3c08142252833ddce1a2b46f76521035"

  event_param(:minimum_reports, {:uint, 256}, :unindexed)
end
