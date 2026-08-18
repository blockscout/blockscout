# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Search.ResultItem do
  @moduledoc """
  This module defines the schema for a single item of the search results.

  Only `tac_operation` is typed so far. The other result types (address, block, transaction,
  token, etc.) are not described individually yet, so additional properties are deliberately
  allowed and this schema only constrains an item that carries a TAC operation.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Search.TacOperation

  OpenApiSpex.schema(%{
    title: "SearchResultItem",
    description: "Single search result. The shape depends on `type`; only `tac_operation` results are fully described.",
    type: :object,
    properties: %{
      tac_operation: TacOperation
    },
    required: []
  })
end
