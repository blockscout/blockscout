defmodule BlockScoutWeb.Schemas.API.V2.Proxy.AccountAbstraction.Paymaster do
  @moduledoc """
  This module defines the schema for the Paymaster struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Address
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Paymaster struct.",
    type: :object,
    properties: %{
      address: Address,
      total_ops: %Schema{type: :integer, nullable: false, minimum: 0}
    },
    required: [
      :address,
      :total_ops
    ],
    nullable: false,
    additionalProperties: false
  })
end
