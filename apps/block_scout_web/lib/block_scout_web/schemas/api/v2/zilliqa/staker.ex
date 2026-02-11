defmodule BlockScoutWeb.Schemas.API.V2.Zilliqa.Staker do
  @moduledoc """
  This module defines the schema for the Zilliqa Staker struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Zilliqa Staker struct.",
    type: :object,
    properties: %{
      balance: General.IntegerString,
      bls_public_key: General.HexString,
      index: %Schema{type: :integer, nullable: false}
    },
    required: [
      :balance,
      :bls_public_key,
      :index
    ],
    additionalProperties: false
  })
end
