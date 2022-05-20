defmodule Explorer.Celo.ContractEvents.Sortedoracles.OracleReportRemovedEvent do
  @moduledoc """
  Struct modelling the OracleReportRemoved event from the Sortedoracles Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "OracleReportRemoved",
    topic: "0xe21a44017b6fa1658d84e937d56ff408501facdb4ff7427c479ac460d76f7893"

  event_param(:token, :address, :indexed)
  event_param(:oracle, :address, :indexed)
end
