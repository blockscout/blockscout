defmodule BlockScoutWeb.Schemas.API.V2.Scroll.Batch do
  @moduledoc """
  This module defines the schema for the Scroll Batch struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Scroll Batch struct.",
    type: :object,
    properties: %{
      number: %Schema{type: :integer},
      transactions_count: %Schema{type: :integer, nullable: true},
      start_block_number: %Schema{type: :integer, nullable: true},
      end_block_number: %Schema{type: :integer, nullable: true},
      data_availability: %Schema{
        type: :object,
        properties: %{
          batch_data_container: %Schema{
            type: :string,
            enum: ["in_blob4844", "in_calldata"],
            nullable: false
          }
        },
        required: [:batch_data_container],
        additionalProperties: false
      },
      commitment_transaction: %Schema{
        type: :object,
        properties: %{
          block_number: %Schema{type: :integer},
          hash: General.FullHash,
          timestamp: General.Timestamp
        },
        required: [:block_number, :hash, :timestamp],
        additionalProperties: false
      },
      confirmation_transaction: %Schema{
        type: :object,
        properties: %{
          block_number: %Schema{type: :integer, nullable: true},
          hash: General.FullHashNullable,
          timestamp: General.TimestampNullable
        },
        required: [:block_number, :hash, :timestamp],
        additionalProperties: false
      }
    },
    required: [
      :number,
      :transactions_count,
      :start_block_number,
      :end_block_number,
      :data_availability,
      :commitment_transaction,
      :confirmation_transaction
    ],
    additionalProperties: false
  })
end
