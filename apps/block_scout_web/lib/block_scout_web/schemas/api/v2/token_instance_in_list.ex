defmodule BlockScoutWeb.Schemas.API.V2.TokenInstanceInList do
  @moduledoc """
  This module defines the schema for the TokenInstanceInList struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{General, Token.Type, TokenInstance}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    allOf: [
      TokenInstance,
      %Schema{
        type: :object,
        nullable: false,
        properties: %{
          token_type: Type,
          value: General.IntegerStringNullable
        },
        required: [:token_type, :value]
      }
    ],
    type: :object
  })
end
