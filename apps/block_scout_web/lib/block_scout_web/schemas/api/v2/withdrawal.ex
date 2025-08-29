defmodule BlockScoutWeb.Schemas.API.V2.Withdrawal do
  @moduledoc """
  This module defines the schema for the Withdrawal struct.
  """
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      index: %Schema{type: :integer, nullable: false},
      validator_index: %Schema{type: :integer, nullable: false},
      amount: General.IntegerString,
      block_number: %Schema{type: :integer, nullable: false},
      receiver: Address,
      timestamp: General.Timestamp
    },
    required: [
      :index,
      :validator_index,
      :amount
    ]
  })
end
