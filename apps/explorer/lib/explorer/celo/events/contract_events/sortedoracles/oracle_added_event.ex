defmodule Explorer.Celo.ContractEvents.Sortedoracles.OracleAddedEvent do
  @moduledoc """
  Struct modelling the OracleAdded event from the Sortedoracles Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "OracleAdded",
    topic: "0x828d2be040dede7698182e08dfa8bfbd663c879aee772509c4a2bd961d0ed43f"

  event_param(:token, :address, :indexed)
  event_param(:oracle_address, :address, :indexed)
end
