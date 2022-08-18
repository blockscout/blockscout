defmodule Explorer.Celo.ContractEvents.Sortedoracles.TokenReportExpirySetEvent do
  @moduledoc """
  Struct modelling the TokenReportExpirySet event from the Sortedoracles Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "TokenReportExpirySet",
    topic: "0xf8324c8592dfd9991ee3e717351afe0a964605257959e3d99b0eb3d45bff9422"

  event_param(:token, :address, :unindexed)
  event_param(:report_expiry, {:uint, 256}, :unindexed)
end
