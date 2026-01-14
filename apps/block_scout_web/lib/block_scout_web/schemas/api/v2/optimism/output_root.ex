defmodule BlockScoutWeb.Schemas.API.V2.Optimism.OutputRoot do
  @moduledoc """
  This module defines the schema for the Optimism Output Root struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Optimism Output Root struct.",
    type: :object,
    properties: %{
      l1_block_number: %Schema{type: :integer},
      l1_timestamp: General.Timestamp,
      l1_transaction_hash: General.FullHash,
      l2_block_number: %Schema{type: :integer},
      l2_output_index: %Schema{type: :integer},
      output_root: General.FullHash
    },
    required: [
      :l1_block_number,
      :l1_timestamp,
      :l1_transaction_hash,
      :l2_block_number,
      :l2_output_index,
      :output_root
    ],
    additionalProperties: false
  })
end
