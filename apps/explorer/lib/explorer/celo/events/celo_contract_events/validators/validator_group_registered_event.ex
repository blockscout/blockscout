defmodule Explorer.Celo.ContractEvents.Validators.ValidatorGroupRegisteredEvent do
  @moduledoc """
  Struct modelling the ValidatorGroupRegistered event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupRegistered",
    topic: "0xbf4b45570f1907a94775f8449817051a492a676918e38108bb762e991e6b58dc"

  event_param(:group, :address, :indexed)
  event_param(:commission, {:uint, 256}, :unindexed)
end
