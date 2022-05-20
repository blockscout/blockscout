defmodule Explorer.Celo.ContractEvents.Escrow.RevocationEvent do
  @moduledoc """
  Struct modelling the Revocation event from the Escrow Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "Revocation",
    topic: "0x6c464fad8039e6f09ec3a57a29f132cf2573d166833256960e2407eefff8f592"

  event_param(:identifier, {:bytes, 32}, :indexed)
  event_param(:by, :address, :indexed)
  event_param(:token, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
  event_param(:payment_id, :address, :unindexed)
end
