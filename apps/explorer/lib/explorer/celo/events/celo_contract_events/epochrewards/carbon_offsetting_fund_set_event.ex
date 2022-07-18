defmodule Explorer.Celo.ContractEvents.Epochrewards.CarbonOffsettingFundSetEvent do
  @moduledoc """
  Struct modelling the CarbonOffsettingFundSet event from the Epochrewards Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "CarbonOffsettingFundSet",
    topic: "0xe296227209b47bb8f4a76768ebd564dcde1c44be325a5d262f27c1fd4fd4538b"

  event_param(:partner, :address, :indexed)
  event_param(:fraction, {:uint, 256}, :unindexed)
end
