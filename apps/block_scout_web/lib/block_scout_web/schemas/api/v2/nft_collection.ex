defmodule BlockScoutWeb.Schemas.API.V2.NFTCollection do
  @moduledoc """
  This module defines the schema for the NFTCollection struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{General, Token, TokenInstanceInList}
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
      }
    },
    required: [:token, :amount, :token_instances],
    additionalProperties: false
  })
end
