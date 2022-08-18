defmodule Explorer.Celo.ContractEvents.Sortedoracles.ReportExpirySetEvent do
  @moduledoc """
  Struct modelling the ReportExpirySet event from the Sortedoracles Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ReportExpirySet",
    topic: "0xc68a9b88effd8a11611ff410efbc83569f0031b7bc70dd455b61344c7f0a042f"

  event_param(:report_expiry, {:uint, 256}, :unindexed)
end
