defmodule Explorer.Celo.ContractEvents.Accounts.AccountCreatedEvent do
  @moduledoc """
  Struct modelling the AccountCreated event from the Accounts Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AccountCreated",
    topic: "0x805996f252884581e2f74cf3d2b03564d5ec26ccc90850ae12653dc1b72d1fa2"

  event_param(:account, :address, :indexed)
end
