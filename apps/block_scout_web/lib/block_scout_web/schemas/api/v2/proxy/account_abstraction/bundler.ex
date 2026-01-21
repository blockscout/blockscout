defmodule BlockScoutWeb.Schemas.API.V2.Proxy.AccountAbstraction.Bundler do
  @moduledoc """
  This module defines the schema for the Bundler struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Address
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Bundler struct.",
    type: :object,
    properties: %{
      address: Address,
      total_bundles: %Schema{type: :integer, nullable: false},
      total_ops: %Schema{type: :integer, nullable: false}
    },
    required: [
      :address,
      :total_bundles,
      :total_ops
    ],
    nullable: false,
    additionalProperties: false
  })
end
