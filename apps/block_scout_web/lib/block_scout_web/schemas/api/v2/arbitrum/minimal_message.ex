defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.MinimalMessage do
  @moduledoc """
  Minimal Arbitrum cross-chain message schema with origination and completion fields only.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Minimal Arbitrum cross-chain message with origination and completion fields.",
    type: :object,
    properties: %{
      origination_transaction_hash: General.FullHashNullable,
      origination_timestamp: General.TimestampNullable,
      origination_transaction_block_number: %Schema{type: :integer, minimum: 0, nullable: true},
      completion_transaction_hash: General.FullHashNullable
    },
    required: [
      :origination_transaction_hash,
      :origination_timestamp,
      :origination_transaction_block_number,
      :completion_transaction_hash
    ],
    additionalProperties: false
  })
end
