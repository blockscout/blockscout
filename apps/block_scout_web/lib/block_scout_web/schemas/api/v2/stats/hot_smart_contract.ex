defmodule BlockScoutWeb.Schemas.API.V2.Stats.HotContract do
  @moduledoc """
  This module defines the schema for the HotContract struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      contract_address: Address,
      transactions_count: %Schema{type: :integer, minimum: 1},
      total_gas_used: %Schema{type: :integer, minimum: 1},
      balance: General.IntegerStringNullable
    },
    required: [:contract_address, :transactions_count, :total_gas_used, :balance],
    additionalProperties: false
  })
end
