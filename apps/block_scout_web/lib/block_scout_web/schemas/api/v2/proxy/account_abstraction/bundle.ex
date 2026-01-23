defmodule BlockScoutWeb.Schemas.API.V2.Proxy.AccountAbstraction.Bundle do
  @moduledoc """
  This module defines the schema for the Bundle struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Bundle struct.",
    type: :object,
    properties: %{
      transaction_hash: General.FullHash,
      bundler: Address,
      block_number: General.IntegerString,
      bundle_index: %Schema{type: :integer, nullable: false, minimum: 0},
      timestamp: General.Timestamp,
      total_ops: %Schema{type: :integer, nullable: false, minimum: 0}
    },
    required: [
      :transaction_hash,
      :bundler,
      :block_number,
      :bundle_index,
      :timestamp,
      :total_ops
    ],
    nullable: false,
    additionalProperties: false
  })
end
