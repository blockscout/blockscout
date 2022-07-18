defmodule Explorer.Celo.ContractEvents.Validators.ValidatorGroupCommissionUpdateQueuedEvent do
  @moduledoc """
  Struct modelling the ValidatorGroupCommissionUpdateQueued event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupCommissionUpdateQueued",
    topic: "0x557d39a57520d9835859d4b7eda805a7f4115a59c3a374eeed488436fc62a152"

  event_param(:group, :address, :indexed)
  event_param(:commission, {:uint, 256}, :unindexed)
  event_param(:activation_block, {:uint, 256}, :unindexed)
end
