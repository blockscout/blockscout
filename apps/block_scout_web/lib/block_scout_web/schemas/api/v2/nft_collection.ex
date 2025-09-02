defmodule BlockScoutWeb.Schemas.API.V2.NFTCollection do
  @moduledoc """
  This module defines the schema for the NFTCollection struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{General, Token, TokenInstanceInList}
  alias Explorer.Chain.Address.Reputation
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      token: Token,
      amount: General.IntegerStringNullable,
      token_instances: %Schema{
        type: :array,
        items: TokenInstanceInList,
        nullable: false
      },
      reputation: %Schema{
        type: :string,
        enum: Reputation.enum_values(),
        description: "Reputation of the token collection",
        nullable: true
      }
    },
    required: [:token, :amount, :token_instances, :reputation],
    additionalProperties: false
  })
end
