defmodule BlockScoutWeb.Schemas.API.V2.Search.Results do
  @moduledoc """
  This module defines the schema for search results response.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SearchResult",
    description: "Search results containing blocks, transactions, and addresses",
    type: :object,
    properties: %{
      items: %Schema{type: :array, items: %Schema{type: :object}},
      next_page_params: %Schema{type: :object, nullable: true}
    },
    required: []
  })
end
