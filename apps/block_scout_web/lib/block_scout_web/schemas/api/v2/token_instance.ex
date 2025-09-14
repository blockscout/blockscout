defmodule BlockScoutWeb.Schemas.API.V2.TokenInstance do
  @moduledoc """
  This module defines the schema for the TokenInstance struct.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema
  alias BlockScoutWeb.Schemas.API.V2.{Address, General, Token}

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      id: General.IntegerString,
      metadata: %Schema{
        type: :object,
        nullable: true,
        example: %{"name" => "Test", "description" => "Test", "image" => "https://example.com/image.png"}
      },
      owner: %Schema{allOf: [Address], nullable: true},
      token: %Schema{allOf: [Token], nullable: true},
      external_app_url: General.URLNullable,
      animation_url: General.URLNullable,
      image_url: General.URLNullable,
      is_unique: %Schema{type: :boolean, nullable: true},
      thumbnails: %Schema{
        type: :object,
        properties: %{
          "500x500" => %Schema{type: :string, format: :uri},
          "250x250" => %Schema{type: :string, format: :uri},
          "60x60" => %Schema{type: :string, format: :uri},
          "original" => %Schema{type: :string, format: :uri}
        },
        required: ["original"],
        nullable: true
      },
      media_type: %Schema{
        type: :string,
        example: "image/png",
        description: "Mime type of the media in media_url",
        nullable: true
      },
      media_url: General.URLNullable
    },
    required: [
      :id,
      :metadata,
      :owner,
      :token,
      :external_app_url,
      :animation_url,
      :image_url,
      :is_unique,
      :thumbnails,
      :media_type,
      :media_url
    ]
  })
end
