defmodule Explorer.Celo.ContractEvents.Accounts.AccountNameSetEvent do
  @moduledoc """
  Struct modelling the AccountNameSet event from the Accounts Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AccountNameSet",
    topic: "0xa6e2c5a23bb917ba0a584c4b250257ddad698685829b66a8813c004b39934fe4"

  event_param(:account, :address, :indexed)
  event_param(:name, :string, :unindexed)
end
