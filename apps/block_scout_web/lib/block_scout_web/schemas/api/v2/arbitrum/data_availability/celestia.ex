defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.DataAvailability.Celestia do
  @moduledoc """
  Data availability information for batches stored on Celestia.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Celestia data availability blob reference.",
    type: :object,
    properties: %{
      # Enum values must be kept in sync with Explorer.Chain.Arbitrum.L1Batch :batch_container field.
      batch_data_container: %Schema{type: :string, enum: ["in_celestia"]},
      height: %Schema{type: :integer, nullable: true, description: "Celestia block height."},
      transaction_commitment: %Schema{
        type: :string,
        nullable: true,
        description: "Celestia transaction commitment hash."
      }
    },
    required: [:batch_data_container, :height, :transaction_commitment],
    additionalProperties: false
  })
end
