defmodule BlockScoutWeb.Schemas.API.V2.Address.TokenBalance do
  @moduledoc """
  This module defines the schema for the TokenBalance struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{General, Token, TokenInstance}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      value: General.IntegerString,
      token: %Schema{allOf: [Token], nullable: true},
      token_id: General.IntegerStringNullable,
      token_instance: %Schema{allOf: [TokenInstance], nullable: true}
    },
    required: [:value, :token, :token_id, :token_instance]
  })
end
