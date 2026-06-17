# SPDX-License-Identifier: LicenseRef-Blockscout
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
      tagType: %Schema{
        type: :string,
        enum: ["name", "generic", "classifier", "information", "note", "protocol"],
        nullable: false
      },
      ordinal: %Schema{type: :integer, nullable: false},
      meta: %Schema{type: :object, nullable: true, additionalProperties: true}
    },
    required: [:slug, :name, :tagType, :ordinal, :meta],
    additionalProperties: false
  })
end
