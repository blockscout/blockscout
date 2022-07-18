defmodule Explorer.Celo.ContractEvents.Accounts.VoteSignerAuthorizedEvent do
  @moduledoc """
  Struct modelling the VoteSignerAuthorized event from the Accounts Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "VoteSignerAuthorized",
    topic: "0xaab5f8a189373aaa290f42ae65ea5d7971b732366ca5bf66556e76263944af28"

  event_param(:account, :address, :indexed)
  event_param(:signer, :address, :unindexed)
end
