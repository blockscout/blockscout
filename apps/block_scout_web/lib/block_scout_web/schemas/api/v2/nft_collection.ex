defmodule BlockScoutWeb.Schemas.API.V2.NFTCollection do
  @moduledoc """
  This module defines the schema for the NFTCollection struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{General, Token, Token.Type, TokenInstance}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      token: Token,
      amount: General.IntegerStringNullable,
      token_instances: %Schema{
        type: :array,
        items: %Schema{
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
          nullable: true
        },
        nullable: false
      }
    },
    required: [:token, :amount, :token_instances]
  })
end
