defmodule Explorer.Celo.ContractEvents.Election.ValidatorGroupMarkedIneligibleEvent do
  @moduledoc """
  Struct modelling the ValidatorGroupMarkedIneligible event from the Election Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupMarkedIneligible",
    topic: "0x5c8cd4e832f3a7d79f9208c2acf25a412143aa3f751cfd3728c42a0fea4921a8"

  event_param(:group, :address, :indexed)
end
