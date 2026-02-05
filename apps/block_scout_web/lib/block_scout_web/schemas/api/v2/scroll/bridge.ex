defmodule BlockScoutWeb.Schemas.API.V2.Scroll.Bridge do
  @moduledoc """
  This module defines the schema for the Scroll Bridge item struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Scroll Bridge item struct.",
    type: :object,
    properties: %{
      completion_transaction_hash: General.FullHashNullable,
      id: %Schema{type: :integer, nullable: true},
      origination_timestamp: General.TimestampNullable,
      origination_transaction_block_number: %Schema{type: :integer, nullable: true},
      origination_transaction_hash: General.FullHashNullable,
      value: General.IntegerStringNullable
    },
    required: [
      :completion_transaction_hash,
      :id,
      :origination_timestamp,
      :origination_transaction_block_number,
      :origination_transaction_hash,
      :value
    ],
    additionalProperties: false
  })
end
