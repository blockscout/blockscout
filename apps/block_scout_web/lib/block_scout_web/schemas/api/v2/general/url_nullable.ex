defmodule BlockScoutWeb.Schemas.API.V2.General.URLNullable do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :string,
    format: :uri,
    example: "https://example.com",
    nullable: true
  })
end
