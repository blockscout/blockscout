defmodule Explorer.Celo.ContractEvents.Sortedoracles.OracleReportedEvent do
  @moduledoc """
  Struct modelling the OracleReported event from the Sortedoracles Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "OracleReported",
    topic: "0x7cebb17173a9ed273d2b7538f64395c0ebf352ff743f1cf8ce66b437a6144213"

  event_param(:token, :address, :indexed)
  event_param(:oracle, :address, :indexed)
  event_param(:timestamp, {:uint, 256}, :unindexed)
  event_param(:value, {:uint, 256}, :unindexed)
end
