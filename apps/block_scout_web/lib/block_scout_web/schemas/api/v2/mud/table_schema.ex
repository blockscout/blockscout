defmodule BlockScoutWeb.Schemas.API.V2.MUD.TableSchema do
  @moduledoc """
  This module defines the schema for the MUD TableSchema struct.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "MUD TableSchema struct.",
    type: :object,
    properties: %{
      key_names: %Schema{type: :array, items: %Schema{type: :string, nullable: false}, nullable: false},
      key_types: %Schema{type: :array, items: %Schema{type: :string, nullable: false}, nullable: false},
      value_names: %Schema{type: :array, items: %Schema{type: :string, nullable: false}, nullable: false},
      value_types: %Schema{type: :array, items: %Schema{type: :string, nullable: false}, nullable: false}
    },
    required: [
      :key_names,
      :key_types,
      :value_names,
      :value_types
    ],
    nullable: false,
    additionalProperties: false
  })
end
