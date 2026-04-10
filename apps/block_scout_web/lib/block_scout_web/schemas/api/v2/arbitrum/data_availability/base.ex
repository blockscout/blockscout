defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.DataAvailability.Base do
  @moduledoc """
  Data availability information for batches using base container types
  (EIP-4844 blobs, calldata, or none).
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Data availability info for batches posted via EIP-4844 blobs, calldata, or with no DA.",
    type: :object,
    properties: %{
      # Enum values must be kept in sync with Explorer.Chain.Arbitrum.L1Batch :batch_container field.
      batch_data_container: %Schema{
        type: :string,
        enum: ["in_blob4844", "in_calldata"],
        nullable: true,
        description: "Data availability container type."
      }
    },
    required: [:batch_data_container],
    additionalProperties: false
  })
end
