defmodule Explorer.Celo.ContractEvents.Sortedoracles.OracleRemovedEvent do
  @moduledoc """
  Struct modelling the OracleRemoved event from the Sortedoracles Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "OracleRemoved",
    topic: "0x6dc84b66cc948d847632b9d829f7cb1cb904fbf2c084554a9bc22ad9d8453340"

  event_param(:token, :address, :indexed)
  event_param(:oracle_address, :address, :indexed)
end
