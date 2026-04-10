defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.DataAvailability.Eigenda do
  @moduledoc """
  Data availability information for batches stored via EigenDA.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "EigenDA data availability blob reference.",
    type: :object,
    properties: %{
      # Enum values must be kept in sync with Explorer.Chain.Arbitrum.L1Batch :batch_container field.
      batch_data_container: %Schema{type: :string, enum: ["in_eigenda"]},
      blob_header: %Schema{
        type: :string,
        nullable: true,
        description: "ABI-encoded EigenDA blob header."
      },
      blob_verification_proof: %Schema{
        type: :string,
        nullable: true,
        description: "ABI-encoded EigenDA blob verification proof."
      }
    },
    required: [:batch_data_container, :blob_header, :blob_verification_proof],
    additionalProperties: false
  })
end
