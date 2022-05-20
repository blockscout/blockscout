defmodule Explorer.Celo.ContractEvents.Reserve.TokenAddedEvent do
  @moduledoc """
  Struct modelling the TokenAdded event from the Reserve Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "TokenAdded",
    topic: "0x784c8f4dbf0ffedd6e72c76501c545a70f8b203b30a26ce542bf92ba87c248a4"

  event_param(:token, :address, :indexed)
end
