# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Search.Results do
  @moduledoc """
  This module defines the schema for search results response.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Search.Result
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SearchResult",
    description: "Search results containing blocks, transactions, and addresses",
    type: :object,
    properties: %{
      items: %Schema{type: :array, items: Result.Item, nullable: false},
      next_page_params: %Schema{type: :object, nullable: true, additionalProperties: true}
    },
    required: [:items, :next_page_params]
  })
end
