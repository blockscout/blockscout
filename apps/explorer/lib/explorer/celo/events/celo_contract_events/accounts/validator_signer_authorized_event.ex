defmodule Explorer.Celo.ContractEvents.Accounts.ValidatorSignerAuthorizedEvent do
  @moduledoc """
  Struct modelling the ValidatorSignerAuthorized event from the Accounts Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorSignerAuthorized",
    topic: "0x16e382723fb40543364faf68863212ba253a099607bf6d3a5b47e50a8bf94943"

  event_param(:account, :address, :indexed)
  event_param(:signer, :address, :unindexed)
end
