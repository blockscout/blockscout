defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Deposit.MainPage do
  @moduledoc """
  This module defines the schema for the Optimism Deposit struct for the main page.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Optimism Deposit struct for the main page.",
    type: :object,
    properties: %{
      l1_block_number: %Schema{type: :integer},
      l1_block_timestamp: General.Timestamp,
      l1_transaction_hash: General.FullHash,
      l2_transaction_hash: General.FullHash
    },
    required: [
      :l1_block_number,
      :l1_block_timestamp,
      :l1_transaction_hash,
      :l2_transaction_hash
    ],
    additionalProperties: false
  })
end
