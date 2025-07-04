defmodule BlockScoutWeb.Schemas.API.V2.CoinBalance do
  @moduledoc """
  This module defines the schema for the CoinBalance struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      transaction_hash: General.FullHashNullable,
      block_number: %Schema{type: :integer, nullable: false},
      delta: General.IntegerString,
      value: General.IntegerString,
      block_timestamp: General.Timestamp
    },
    required: [
      :transaction_hash,
      :block_number,
      :delta,
      :value,
      :block_timestamp
    ]
  })
end
