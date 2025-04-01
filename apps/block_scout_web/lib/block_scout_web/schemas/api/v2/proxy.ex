defmodule BlockScoutWeb.Schemas.API.V2.Proxy do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule MetadataTag do
    OpenApiSpex.schema(%{
      description: "Metadata tag struct",
      type: :object,
      properties: %{
        slug: %Schema{type: :string, nullable: false},
        name: %Schema{type: :string, nullable: false},
        tagType: %Schema{type: :string, nullable: false},
        ordinal: %Schema{type: :string, nullable: false},
        meta: %Schema{type: :object, nullable: false}
      },
      required: [:slug, :name, :tagType, :ordinal, :meta]
    })
  end

  defmodule Metadata do
    OpenApiSpex.schema(%{
      description: "Metadata struct",
      type: :object,
      properties: %{
        tags: %Schema{description: "Metadata tags linked with the address", type: :array, items: MetadataTag}
      },
      required: [:tags]
    })
  end
end
