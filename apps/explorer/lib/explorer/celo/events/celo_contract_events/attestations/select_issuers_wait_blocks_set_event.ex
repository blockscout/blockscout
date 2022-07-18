defmodule Explorer.Celo.ContractEvents.Attestations.SelectIssuersWaitBlocksSetEvent do
  @moduledoc """
  Struct modelling the SelectIssuersWaitBlocksSet event from the Attestations Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "SelectIssuersWaitBlocksSet",
    topic: "0x954fa47fa6f4e8017b99f93c73f4fbe599d786f9f5da73fe9086ab473fb455d8"

  event_param(:value, {:uint, 256}, :unindexed)
end
