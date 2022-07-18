defmodule Explorer.Celo.ContractEvents.Downtimeslasher.DowntimeSlashPerformedEvent do
  @moduledoc """
  Struct modelling the DowntimeSlashPerformed event from the Downtimeslasher Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "DowntimeSlashPerformed",
    topic: "0x229d63d990a0f1068a86ee5bdce0b23fe156ff5d5174cc634d5da8ed3618e0c9"

  event_param(:validator, :address, :indexed)
  event_param(:start_block, {:uint, 256}, :indexed)
  event_param(:end_block, {:uint, 256}, :indexed)
end
