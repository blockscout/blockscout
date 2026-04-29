defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.BatchDataContainer do
  @moduledoc """
  Data availability container type for Arbitrum batches.
  """
  require OpenApiSpex

  # Enum values must be kept in sync with Explorer.Chain.Arbitrum.L1Batch :batch_container field.
  OpenApiSpex.schema(%{
    type: :string,
    enum: ["in_blob4844", "in_calldata", "in_celestia", "in_anytrust", "in_eigenda"],
    nullable: true,
    description: "Data availability container type."
  })
end
