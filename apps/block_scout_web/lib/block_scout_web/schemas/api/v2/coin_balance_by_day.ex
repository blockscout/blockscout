defmodule BlockScoutWeb.Schemas.API.V2.CoinBalanceByDay do
  @moduledoc """
  This module defines the schema for the CoinBalanceByDay struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      date: %Schema{type: :string, format: :date, nullable: false},
      value: General.IntegerString
    },
    required: [:date, :value]
  })
end
