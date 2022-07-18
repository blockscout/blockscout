defmodule Explorer.Celo.ContractEvents.Escrow.WithdrawalEvent do
  @moduledoc """
  Struct modelling the Withdrawal event from the Escrow Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "Withdrawal",
    topic: "0xab4f92d461fdbd1af5db2375223d65edb43bcb99129b19ab4954004883e52025"

  event_param(:identifier, {:bytes, 32}, :indexed)
  event_param(:to, :address, :indexed)
  event_param(:token, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
  event_param(:payment_id, :address, :unindexed)
end
