defmodule BlockScoutWeb.Schemas.API.V2.MUD.World do
  @moduledoc """
  This module defines the schema for the MUD World struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "MUD World struct.",
    type: :object,
    properties: %{
      address: Address.schema(),
      coin_balance: General.IntegerStringNullable,
      transactions_count: %Schema{type: :integer, nullable: true}
    },
    required: [
      :address,
      :coin_balance,
      :transactions_count
    ],
    nullable: false,
    additionalProperties: false
  })
end
