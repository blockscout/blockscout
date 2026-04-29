defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.DataAvailability.Anytrust do
  @moduledoc """
  Data availability information for batches stored via AnyTrust committee.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "AnyTrust data availability certificate.",
    type: :object,
    properties: %{
      # Enum values must be kept in sync with Explorer.Chain.Arbitrum.L1Batch :batch_container field.
      batch_data_container: %Schema{type: :string, enum: ["in_anytrust"]},
      data_hash: %Schema{type: :string, nullable: true, description: "AnyTrust data hash."},
      timeout: %Schema{type: :string, nullable: true, description: "Data availability timeout (ISO 8601)."},
      bls_signature: %Schema{
        type: :string,
        nullable: true,
        description: "Aggregated BLS signature of committee members."
      },
      signers: %Schema{
        type: :array,
        description: "Committee members who guaranteed data availability.",
        items: %Schema{
          type: :object,
          properties: %{
            trusted: %Schema{type: :boolean, description: "Whether the signer is a trusted member."},
            key: %Schema{type: :string, description: "BLS public key."},
            proof: %Schema{type: :string, description: "Proof of possession (absent for trusted members)."}
          },
          required: [:trusted, :key],
          additionalProperties: false
        }
      }
    },
    required: [:batch_data_container, :data_hash, :timeout, :bls_signature, :signers],
    additionalProperties: false
  })
end
