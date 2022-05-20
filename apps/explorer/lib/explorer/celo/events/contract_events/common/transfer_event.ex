defmodule Explorer.Celo.ContractEvents.Common.TransferEvent do
  @moduledoc """
  Struct modelling the Transfer event from the Stabletoken, Goldtoken, Erc20, Stabletokenbrl, Stabletokeneur Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "Transfer",
    topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  event_param(:from, :address, :indexed)
  event_param(:to, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
end
