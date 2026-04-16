defmodule BlockScoutWeb.Schemas.API.V2.Legacy.GetBlockNumberByTimeResult do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      blockNumber: %Schema{
        description: "Decimal-string block number.",
        allOf: [General.IntegerString]
      }
    },
    required: [:blockNumber],
    additionalProperties: false,
    nullable: true
  })
end
