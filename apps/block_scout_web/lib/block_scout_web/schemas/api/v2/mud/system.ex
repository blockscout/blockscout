defmodule BlockScoutWeb.Schemas.API.V2.MUD.System do
  @moduledoc """
  This module defines the schema for the MUD System struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "MUD System struct.",
    type: :object,
    properties: %{
      name: %Schema{type: :string, nullable: false},
      address_hash: General.AddressHash
    },
    required: [
      :name,
      :address_hash
    ],
    nullable: false,
    additionalProperties: false
  })
end
