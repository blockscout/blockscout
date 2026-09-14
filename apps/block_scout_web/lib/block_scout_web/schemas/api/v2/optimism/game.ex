# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Game do
  @moduledoc """
  This module defines the schema for the Optimism Dispute Game struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Optimism Dispute Game struct.",
    type: :object,
    properties: %{
      contract_address_hash: General.AddressHash,
      created_at: General.Timestamp,
      game_type: %Schema{type: :integer},
      index: %Schema{type: :integer},
      l2_block_number: %Schema{
        type: :integer,
        description: "L2 block number the game is bound to. `null` for the games with Super Root claim.",
        nullable: true
      },
      l2_timestamp: General.TimestampNullable,
      resolved_at: General.TimestampNullable,
      status: %Schema{
        type: :string,
        enum: ["In progress", "Challenger wins", "Defender wins"],
        nullable: false
      }
    },
    required: [
      :contract_address_hash,
      :created_at,
      :game_type,
      :index,
      :l2_block_number,
      :l2_timestamp,
      :resolved_at,
      :status
    ],
    additionalProperties: false
  })
end
