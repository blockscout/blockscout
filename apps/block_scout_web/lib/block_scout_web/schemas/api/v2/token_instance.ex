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
      token: Token,
      external_app_url: General.URLWithIPFSNullable,
      animation_url: General.URLWithIPFSNullable,
      image_url: General.URLWithIPFSNullable,
      is_unique: %Schema{type: :boolean, nullable: false},
      thumbnails: %Schema{
        type: :object,
        properties: %{
          "500x500" => %Schema{type: :string, format: :uri},
          "250x250" => %Schema{type: :string, format: :uri},
          "60x60" => %Schema{type: :string, format: :uri},
          "original" => %Schema{type: :string, format: :uri}
        },
        required: ["original"]
      },
      media_type: %Schema{type: :string, example: "image/png", description: "Mime type of the media in media_url"},
      media_url: General.URLWithIPFSNullable
    }
  })
end
