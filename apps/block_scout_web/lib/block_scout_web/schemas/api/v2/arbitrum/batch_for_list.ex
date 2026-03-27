defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.BatchForList do
  @moduledoc """
  Schema for an Arbitrum batch item in list responses.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Arbitrum batch summary for list endpoints.",
    type: :object,
    properties: %{
      number: %Schema{type: :integer, description: "Batch number."},
      transactions_count: %Schema{type: :integer, description: "Number of transactions in the batch."},
      blocks_count: %Schema{type: :integer, description: "Number of blocks included in the batch."},
      batch_data_container: %Schema{
        type: :string,
        enum: ["in_blob4844", "in_calldata", "in_celestia", "in_anytrust", "in_eigenda"],
        nullable: true,
        description: "Data availability container type."
      },
      commitment_transaction: %Schema{
        type: :object,
        description: "L1 transaction that committed the batch.",
        properties: %{
          hash: General.FullHashNullable,
          block_number: %Schema{type: :integer, nullable: true},
          timestamp: General.TimestampNullable,
          status: %Schema{type: :string, nullable: true, description: "Finalization status of the L1 transaction."}
        },
        required: [:hash, :block_number, :timestamp, :status],
        additionalProperties: false
      }
    },
    required: [:number, :transactions_count, :blocks_count, :batch_data_container, :commitment_transaction],
    additionalProperties: false
  })
end
