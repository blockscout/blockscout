defmodule BlockScoutWeb.Schemas.API.V2.Celo.Epoch do
  @moduledoc """
  This module defines the schema for a Celo epoch list item.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Celo epoch summary.",
    type: :object,
    properties: %{
      number: %Schema{type: :integer, nullable: false, minimum: 0},
      type: %Schema{type: :string, enum: ["L1", "L2"], nullable: false},
      start_block_number: %Schema{type: :integer, nullable: false, minimum: 0},
      end_block_number: %Schema{type: :integer, nullable: false, minimum: 0},
      timestamp: General.TimestampNullable,
      is_finalized: %Schema{type: :boolean, nullable: false},
      distribution: %Schema{type: :object, nullable: true, additionalProperties: true}
    },
    required: [
      :number,
      :type,
      :start_block_number,
      :end_block_number,
      :timestamp,
      :is_finalized,
      :distribution
    ],
    additionalProperties: false
  })
end
