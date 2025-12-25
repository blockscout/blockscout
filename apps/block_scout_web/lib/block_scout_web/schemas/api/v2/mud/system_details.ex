defmodule BlockScoutWeb.Schemas.API.V2.MUD.SystemDetails do
  @moduledoc """
  This module defines the schema for the MUD SystemDetails struct.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "MUD SystemDetails struct.",
    type: :object,
    properties: %{
      name: %Schema{type: :string, nullable: false},
      abi: %Schema{type: :array, items: %Schema{type: :object}, nullable: false}
    },
    required: [
      :name,
      :abi
    ],
    nullable: false,
    additionalProperties: false
  })
end
