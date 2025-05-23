defmodule BlockScoutWeb.Schemas.API.V2.Transaction.Fee do
  @moduledoc """
  This module defines the schema for the Transaction fee.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    required: [:type, :value],
    properties: %{
      type: %Schema{
        type: :string,
        enum: ["maximum", "actual"]
      },
      value: General.IntegerStringNullable
    }
  })
end
