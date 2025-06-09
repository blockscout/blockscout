defmodule BlockScoutWeb.Schemas.API.V2.Log do
  @moduledoc """
  This module defines the schema for the Log struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      transaction_hash: General.FullHash,
      address: Address,
      topics: %Schema{type: :array, items: General.HexStringNullable, nullable: false},
      data: General.HexString,
      index: %Schema{type: :integer, nullable: false},
      decoded: %Schema{allOf: [General.DecodedInput], nullable: true},
      smart_contract: %Schema{oneOf: [Address], nullable: true},
      block_hash: General.FullHash,
      block_number: %Schema{type: :integer, nullable: false}
    },
    required: [
      :transaction_hash,
      :address,
      :topics,
      :data,
      :index,
      :decoded,
      :smart_contract,
      :block_hash,
      :block_number
    ]
  })
end
