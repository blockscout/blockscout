defmodule BlockScoutWeb.Schemas.API.V2.Token.Response do
  @moduledoc """
  This module defines the schema for token response from /api/v2/tokens/:token_address_param.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Token
  alias BlockScoutWeb.Schemas.Helper

  OpenApiSpex.schema(
    Token.schema()
    |> Helper.extend_schema(
      title: "TokenResponse",
      description: "Token response",
      additionalProperties: false
    )
  )
end
