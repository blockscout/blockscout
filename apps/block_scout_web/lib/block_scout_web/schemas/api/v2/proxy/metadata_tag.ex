defmodule BlockScoutWeb.Schemas.API.V2.Proxy.MetadataTag do
  @moduledoc """
  This module defines the schema for the MetadataTag struct.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Metadata tag struct",
    type: :object,
    properties: %{
      slug: %Schema{type: :string, nullable: false},
      name: %Schema{type: :string, nullable: false},
      tagType: %Schema{type: :string, nullable: false},
      ordinal: %Schema{type: :integer, nullable: false},
      meta: %Schema{type: :object, nullable: false}
    },
    required: [:slug, :name, :tagType, :ordinal, :meta]
  })
end
