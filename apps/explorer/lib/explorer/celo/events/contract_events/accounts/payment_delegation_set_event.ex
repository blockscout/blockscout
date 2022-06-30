defmodule Explorer.Celo.ContractEvents.Accounts.PaymentDelegationSetEvent do
  @moduledoc """
  Struct modelling the PaymentDelegationSet event from the Accounts Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "PaymentDelegationSet",
    topic: "0x3bff8b126c8f283f709ae37dc0d3fc03cae85ca4772cfb25b601f4b0b49ca6df"

  event_param(:beneficiary, :address, :indexed)
  event_param(:fraction, {:uint, 256}, :unindexed)
end
