defmodule Explorer.Celo.ContractEvents.Downtimeslasher.BitmapSetForIntervalEvent do
  @moduledoc """
  Struct modelling the BitmapSetForInterval event from the Downtimeslasher Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "BitmapSetForInterval",
    topic: "0x0aa96aa275a5f936eed2a6a01f082594744dcc2510f575101366f8f479f03235"

  event_param(:sender, :address, :indexed)
  event_param(:start_block, {:uint, 256}, :indexed)
  event_param(:end_block, {:uint, 256}, :indexed)
  event_param(:bitmap, {:bytes, 32}, :unindexed)
end
