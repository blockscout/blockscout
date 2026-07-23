# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Block.Countdown do
  @moduledoc """
  This module defines the schema for block countdown response from /api/v2/blocks/:block_number/countdown.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "BlockCountdown",
    description: "Block countdown information showing estimated time until a target block is reached",
    type: :object,
    additionalProperties: false,
    properties: %{
      current_block_number: %Schema{
        type: :integer,
        description: "The current highest block number in the blockchain",
        minimum: 0,
        example: 22_566_361
      },
      countdown_block_number: %Schema{
        type: :integer,
        description: "The target block number for the countdown",
        minimum: 0,
        example: 22_600_000
      },
      remaining_blocks_count: %Schema{
        type: :integer,
        description: "Number of blocks remaining until the target block is reached",
        minimum: 0,
        example: 33_639
      },
      estimated_time_in_seconds: %Schema{
        type: :string,
        description: "Estimated time in seconds until the target block is reached",
        example: "404868.0"
      }
    },
    required: [
      :current_block_number,
      :countdown_block_number,
      :remaining_blocks_count,
      :estimated_time_in_seconds
    ],
    example: %{
      current_block_number: 22_566_361,
      countdown_block_number: 22_600_000,
      remaining_blocks_count: 33_639,
      estimated_time_in_seconds: "404868.0"
    }
  })
end
