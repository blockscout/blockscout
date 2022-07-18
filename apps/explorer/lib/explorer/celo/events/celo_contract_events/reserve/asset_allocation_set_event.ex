defmodule Explorer.Celo.ContractEvents.Reserve.AssetAllocationSetEvent do
  @moduledoc """
  Struct modelling the AssetAllocationSet event from the Reserve Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AssetAllocationSet",
    topic: "0x55b488abd19ae7621712324d3d42c2ef7a9575f64f5503103286a1161fb40855"

  event_param(:symbols, {:array, {:bytes, 32}}, :unindexed)
  event_param(:weights, {:array, {:uint, 256}}, :unindexed)
end
