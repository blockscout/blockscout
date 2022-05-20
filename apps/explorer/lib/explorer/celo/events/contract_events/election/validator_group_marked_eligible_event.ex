defmodule Explorer.Celo.ContractEvents.Election.ValidatorGroupMarkedEligibleEvent do
  @moduledoc """
  Struct modelling the ValidatorGroupMarkedEligible event from the Election Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupMarkedEligible",
    topic: "0x8f21dc7ff6f55d73e4fca52a4ef4fcc14fbda43ac338d24922519d51455d39c1"

  event_param(:group, :address, :indexed)
end
