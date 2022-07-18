defmodule Explorer.Celo.ContractEvents.Validators.ValidatorGroupMemberAddedEvent do
  @moduledoc """
  Struct modelling the ValidatorGroupMemberAdded event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupMemberAdded",
    topic: "0xbdf7e616a6943f81e07a7984c9d4c00197dc2f481486ce4ffa6af52a113974ad"

  event_param(:group, :address, :indexed)
  event_param(:validator, :address, :indexed)
end
