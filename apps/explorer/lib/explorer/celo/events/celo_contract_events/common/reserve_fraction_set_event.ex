defmodule Explorer.Celo.ContractEvents.Common.ReserveFractionSetEvent do
  @moduledoc """
  Struct modelling the ReserveFractionSet event from the Exchange, Exchangebrl, Exchangeeur Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ReserveFractionSet",
    topic: "0xb690f84efb1d9039c2834effb7bebc792a85bfec7ef84f4b269528454f363ccf"

  event_param(:reserve_fraction, {:uint, 256}, :unindexed)
end
