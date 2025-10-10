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
    properties: %{
      current_block: %Schema{
        type: :integer,
        description: "The current highest block number in the blockchain",
        minimum: 0,
        example: 22_566_361
      },
      countdown_block: %Schema{
        type: :integer,
        description: "The target block number for the countdown",
        minimum: 0,
        example: 22_600_000
      },
      remaining_blocks: %Schema{
        type: :integer,
        description: "Number of blocks remaining until the target block is reached",
        minimum: 0,
        example: 33_639
      },
      estimated_time_in_sec: %Schema{
        type: :number,
        format: :float,
        description: "Estimated time in seconds until the target block is reached",
        minimum: 0,
        example: 404_868.0
      }
    },
    required: [
      :current_block,
      :countdown_block,
      :remaining_blocks,
      :estimated_time_in_sec
    ],
    example: %{
      current_block: 22_566_361,
      countdown_block: 22_600_000,
      remaining_blocks: 33_639,
      estimated_time_in_sec: 404_868.0
    }
  })
end
