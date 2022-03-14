defmodule Explorer.Celo.ContractEvents.Goldtoken.TransferCommentEvent do
  @moduledoc """
  Struct modelling the TransferComment event from the Goldtoken Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "TransferComment",
    topic: "0xe5d4e30fb8364e57bc4d662a07d0cf36f4c34552004c4c3624620a2c1d1c03dc"

  event_param(:comment, :string, :unindexed)
end
