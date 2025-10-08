defmodule BlockScoutWeb.Schemas.API.V2.Token.Counters do
  @moduledoc """
  This module defines the schema for the response from /api/v2/tokens/:address_hash_param/counters.
  Example response: {"token_holders_count":"0","transfers_count":"0"}
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%Schema{
    title: "TokenCountersResponse",
    description: "Token counters response",
    type: :object,
    properties: %{
      token_holders_count: General.IntegerString,
      transfers_count: General.IntegerString
    },
    required: [:token_holders_count, :transfers_count],
    additionalProperties: false,
    example: %{token_holders_count: "0", transfers_count: "0"}
  })
end
