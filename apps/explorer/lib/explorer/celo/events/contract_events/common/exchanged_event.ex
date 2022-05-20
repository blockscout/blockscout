defmodule Explorer.Celo.ContractEvents.Common.ExchangedEvent do
  @moduledoc """
  Struct modelling the Exchanged event from the Exchange, Exchangebrl, Exchangeeur Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "Exchanged",
    topic: "0x402ac9185b4616422c2794bf5b118bfcc68ed496d52c0d9841dfa114fdeb05ba"

  event_param(:exchanger, :address, :indexed)
  event_param(:sell_amount, {:uint, 256}, :unindexed)
  event_param(:buy_amount, {:uint, 256}, :unindexed)
  event_param(:sold_gold, :bool, :unindexed)
end
