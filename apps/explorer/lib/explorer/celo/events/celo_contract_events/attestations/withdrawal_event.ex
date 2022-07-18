defmodule Explorer.Celo.ContractEvents.Attestations.WithdrawalEvent do
  @moduledoc """
  Struct modelling the Withdrawal event from the Attestations Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "Withdrawal",
    topic: "0x2717ead6b9200dd235aad468c9809ea400fe33ac69b5bfaa6d3e90fc922b6398"

  event_param(:account, :address, :indexed)
  event_param(:token, :address, :indexed)
  event_param(:amount, {:uint, 256}, :unindexed)
end
