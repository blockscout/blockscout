defmodule Explorer.Celo.ContractEvents.Accounts.AttestationSignerAuthorizedEvent do
  @moduledoc """
  Struct modelling the AttestationSignerAuthorized event from the Accounts Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AttestationSignerAuthorized",
    topic: "0x9dfbc5a621c3e2d0d83beee687a17dfc796bbce2118793e5e254409bb265ca0b"

  event_param(:account, :address, :indexed)
  event_param(:signer, :address, :unindexed)
end
