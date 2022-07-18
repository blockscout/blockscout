defmodule Explorer.Celo.ContractEvents.Common.BucketsUpdatedEvent do
  @moduledoc """
  Struct modelling the BucketsUpdated event from the Exchange, Exchangebrl, Exchangeeur Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "BucketsUpdated",
    topic: "0xa18ec663cb684011386aa866c4dacb32d2d2ad859a35d3440b6ce7200a76bad8"

  event_param(:gold_bucket, {:uint, 256}, :unindexed)
  event_param(:stable_bucket, {:uint, 256}, :unindexed)
end
