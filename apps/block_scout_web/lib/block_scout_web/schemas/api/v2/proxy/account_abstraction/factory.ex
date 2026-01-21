defmodule BlockScoutWeb.Schemas.API.V2.Proxy.AccountAbstraction.Factory do
  @moduledoc """
  This module defines the schema for the Factory struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Address
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Factory struct.",
    type: :object,
    properties: %{
      address: Address,
      total_accounts: %Schema{type: :integer, nullable: false}
    },
    required: [
      :address,
      :total_accounts
    ],
    nullable: false,
    additionalProperties: false
  })
end
