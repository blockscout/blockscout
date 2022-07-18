defmodule Explorer.Celo.ContractEvents.Common.UpdateFrequencySetEvent do
  @moduledoc """
  Struct modelling the UpdateFrequencySet event from the Exchange, Exchangebrl, Exchangeeur Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "UpdateFrequencySet",
    topic: "0x90c0a4a142fbfbc2ae8c21f50729a2f4bc56e85a66c1a1b6654f1e85092a54a6"

  event_param(:update_frequency, {:uint, 256}, :unindexed)
end
