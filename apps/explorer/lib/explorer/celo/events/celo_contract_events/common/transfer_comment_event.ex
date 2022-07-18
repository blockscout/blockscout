defmodule Explorer.Celo.ContractEvents.Common.TransferCommentEvent do
  @moduledoc """
  Struct modelling the TransferComment event from the Stabletoken, Goldtoken, Stabletokenbrl, Stabletokeneur Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "TransferComment",
    topic: "0xe5d4e30fb8364e57bc4d662a07d0cf36f4c34552004c4c3624620a2c1d1c03dc"

  event_param(:comment, :string, :unindexed)
end
