defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.Detailed do
  @moduledoc """
  This module defines the schema for batch response from /api/v2/optimism/batches/:number and
  /api/v2/optimism/batches/da/celestia/:height/:commitment
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.Optimism.Batch
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    Batch.schema()
    |> Helper.extend_schema(
      nullable: true,
      properties: %{
        blobs: %Schema{
          type: :array,
          items: %Schema{
            description: "Blob struct bound with Optimism batch.",
            type: :object,
            properties: %{
              hash: %Schema{
                type: :string,
                pattern: General.hex_string_pattern(),
                nullable: false,
                description: "EIP-4844 blob hash."
              },
              l1_transaction_hash: %Schema{
                type: :string,
                pattern: General.full_hash_pattern(),
                nullable: false,
                description: "L1 transaction hash bound with the blob."
              },
              l1_timestamp: %Schema{
                type: :string,
                format: :"date-time",
                nullable: false,
                description: "L1 transaction timestamp bound with the blob."
              },
              height: %Schema{type: :integer, nullable: false, description: "Celestia block height."},
              namespace: %Schema{
                type: :string,
                pattern: General.hex_string_pattern(),
                nullable: false,
                description: "Celestia blob namespace."
              },
              commitment: %Schema{
                type: :string,
                pattern: General.hex_string_pattern(),
                nullable: false,
                description: "Celestia or Alt-DA blob commitment."
              },
              cert: %Schema{
                type: :string,
                pattern: General.hex_string_pattern(),
                nullable: false,
                description: "EigenDA cert raw bytes."
              }
            },
            required: [
              :l1_transaction_hash,
              :l1_timestamp
            ],
            additionalProperties: false
          },
          nullable: false
        }
      }
    )
  )
end
