defmodule Explorer.Celo.ContractEvents.Lockedgold.SlasherWhitelistAddedEvent do
  @moduledoc """
  Struct modelling the SlasherWhitelistAdded event from the Lockedgold Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "SlasherWhitelistAdded",
    topic: "0x92a16cb9e1846d175c3007fc61953d186452c9ea1aa34183eb4b7f88cd3f07bb"

  event_param(:slasher_identifier, :string, :indexed)
end
