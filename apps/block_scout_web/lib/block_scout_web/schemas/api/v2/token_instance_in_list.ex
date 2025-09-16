defmodule BlockScoutWeb.Schemas.API.V2.TokenInstanceInList do
  @moduledoc """
  This module defines the schema for the TokenInstanceInList struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{General, Token.Type, TokenInstance}
  alias BlockScoutWeb.Schemas.Helper
  alias Explorer.Chain.Address.Reputation
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    TokenInstance.schema()
    |> Helper.extend_schema(
      title: "TokenInstanceInList",
      properties: %{
        token_type: Type,
        value: General.IntegerStringNullable,
        reputation: %Schema{
          type: :string,
          enum: Reputation.enum_values(),
          description: "Reputation of the token instance",
          nullable: true
        }
      },
      required: [:token_type, :value, :reputation]
    )
  )
end
