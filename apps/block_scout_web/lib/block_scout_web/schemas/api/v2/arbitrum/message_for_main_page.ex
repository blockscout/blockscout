defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.MessageForMainPage do
  @moduledoc """
  Schema for an Arbitrum L1-to-L2 message item on the main page.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Arbitrum L1-to-L2 message summary for the main page.",
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
