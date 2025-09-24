defmodule BlockScoutWeb.Schemas.API.V2.Block.Response do
  @moduledoc """
  This module defines the schema for block response from /api/v2/blocks/:hash_or_number.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Block.Common
  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "BlockResponse",
    description: "Block response",
    type: :object,
    allOf: [
      BlockScoutWeb.Schemas.API.V2.Block,
      struct(
        Schema,
        %{
          type: :object,
          properties: %{
            burnt_fees: General.IntegerStringNullable,
            burnt_fees_percentage: %Schema{type: :number, format: :float, nullable: true},
            difficulty: General.IntegerStringNullable,
            withdrawals_count: %Schema{type: :integer, minimum: 0, nullable: true},
            beacon_deposits_count: %Schema{type: :integer, minimum: 0, nullable: true},
            blob_transactions_count: %Schema{type: :integer, minimum: 0, nullable: true},
            priority_fee: General.IntegerStringNullable,
            base_fee_per_gas: General.IntegerStringNullable,
            blob_gas_price: General.IntegerStringNullable,
            blob_gas_used: General.IntegerStringNullable,
            excess_blob_gas: General.IntegerStringNullable,
            uncles: %Schema{
              type: :array,
              items: General.FullHash,
              nullable: true
            },
            rewards: Common.rewards_schema()
          },
          required: [
            :burnt_fees,
            :burnt_fees_percentage,
            :priority_fee,
            :base_fee_per_gas,
            :rewards
          ]
        }
      )
    ]
  })
end
