defmodule Explorer.Celo.ContractEvents.Governance.ReferendumStageDurationSetEvent do
  @moduledoc """
  Struct modelling the ReferendumStageDurationSet event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ReferendumStageDurationSet",
    topic: "0x90290eb9b27055e686a69fb810bada5381e544d07b8270021da2d355a6c96ed6"

  event_param(:referendum_stage_duration, {:uint, 256}, :unindexed)
end
