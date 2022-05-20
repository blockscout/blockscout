defmodule Explorer.Celo.ContractEvents.Validators.ValidatorGroupMemberReorderedEvent do
  @moduledoc """
  Struct modelling the ValidatorGroupMemberReordered event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupMemberReordered",
    topic: "0x38819cc49a343985b478d72f531a35b15384c398dd80fd191a14662170f895c6"

  event_param(:group, :address, :indexed)
  event_param(:validator, :address, :indexed)
end
