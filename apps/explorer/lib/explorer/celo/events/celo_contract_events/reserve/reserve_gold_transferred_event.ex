defmodule Explorer.Celo.ContractEvents.Reserve.ReserveGoldTransferredEvent do
  @moduledoc """
  Struct modelling the ReserveGoldTransferred event from the Reserve Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ReserveGoldTransferred",
    topic: "0x4dd1abe16ad3d4f829372dc77766ca2cce34e205af9b10f8cc1fab370425864f"

  event_param(:spender, :address, :indexed)
  event_param(:to, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
end
