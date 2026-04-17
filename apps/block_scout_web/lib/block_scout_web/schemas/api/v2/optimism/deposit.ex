defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Deposit do
  @moduledoc """
  This module defines the schema for the Optimism Deposit struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Optimism Deposit struct.",
    type: :object,
    properties: %{
      l1_block_number: %Schema{type: :integer},
      l1_block_timestamp: General.Timestamp,
      l1_transaction_hash: General.FullHash,
      l1_transaction_origin: General.AddressHash,
      l2_transaction_gas_limit: General.IntegerString,
      l2_transaction_hash: General.FullHash
    },
    required: [
      :l1_block_number,
      :l1_block_timestamp,
      :l1_transaction_hash,
      :l1_transaction_origin,
      :l2_transaction_gas_limit,
      :l2_transaction_hash
    ],
    additionalProperties: false
  })
end
