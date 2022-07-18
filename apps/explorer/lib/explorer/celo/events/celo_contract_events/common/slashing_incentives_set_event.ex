defmodule Explorer.Celo.ContractEvents.Common.SlashingIncentivesSetEvent do
  @moduledoc """
  Struct modelling the SlashingIncentivesSet event from the Doublesigningslasher, Downtimeslasher Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "SlashingIncentivesSet",
    topic: "0x716dc7c34384df36c6ccc5a2949f2ce9b019f5d4075ef39139a80038a4fdd1c3"

  event_param(:penalty, {:uint, 256}, :unindexed)
  event_param(:reward, {:uint, 256}, :unindexed)
end
