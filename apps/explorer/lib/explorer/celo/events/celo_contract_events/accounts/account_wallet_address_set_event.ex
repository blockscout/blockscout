defmodule Explorer.Celo.ContractEvents.Accounts.AccountWalletAddressSetEvent do
  @moduledoc """
  Struct modelling the AccountWalletAddressSet event from the Accounts Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AccountWalletAddressSet",
    topic: "0xf81d74398fd47e35c36b714019df15f200f623dde569b5b531d6a0b4da5c5f26"

  event_param(:account, :address, :indexed)
  event_param(:wallet_address, :address, :unindexed)
end
