defmodule BlockScoutWeb.Schemas.API.V2.General.WatchlistName do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Watchlist name struct",
    type: :object,
    properties: %{
      display_name: %Schema{type: :string, nullable: false},
      label: %Schema{type: :string, nullable: false}
    },
    required: [:display_name, :label],
    additionalProperties: false
  })
end
