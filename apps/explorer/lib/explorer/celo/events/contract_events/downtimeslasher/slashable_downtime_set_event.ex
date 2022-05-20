defmodule Explorer.Celo.ContractEvents.Downtimeslasher.SlashableDowntimeSetEvent do
  @moduledoc """
  Struct modelling the SlashableDowntimeSet event from the Downtimeslasher Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "SlashableDowntimeSet",
    topic: "0xc3293b70d45615822039f6f13747ece88efbbb4e645c42070413a6c3fd21d771"

  event_param(:interval, {:uint, 256}, :unindexed)
end
