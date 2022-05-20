defmodule Explorer.Celo.ContractEvents.Validators.ValidatorGroupMemberRemovedEvent do
  @moduledoc """
  Struct modelling the ValidatorGroupMemberRemoved event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupMemberRemoved",
    topic: "0xc7666a52a66ff601ff7c0d4d6efddc9ac20a34792f6aa003d1804c9d4d5baa57"

  event_param(:group, :address, :indexed)
  event_param(:validator, :address, :indexed)
end
