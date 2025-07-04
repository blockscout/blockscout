defmodule BlockScoutWeb.Schemas.API.V2.Proxy.Metadata do
  @moduledoc """
  This module defines the schema for the Metadata struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Proxy.MetadataTag
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Metadata struct",
    type: :object,
    properties: %{
      tags: %Schema{description: "Metadata tags linked with the address", type: :array, items: MetadataTag}
    },
    required: [:tags]
  })
end
