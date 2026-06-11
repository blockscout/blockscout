# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.TokenInstanceInTokenInstancesList do
  @moduledoc """
  This module defines the schema for a token instance item returned by the
  `GET /api/v2/tokens/:address_hash/instances` endpoint. Unlike TokenInstanceInList,
  the `token` field is omitted because all items belong to the same token contract.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.TokenInstanceInList
  alias BlockScoutWeb.Schemas.Helper

  OpenApiSpex.schema(
    TokenInstanceInList.schema()
    |> Helper.extend_schema(title: "TokenInstanceInTokenInstancesList")
    |> Map.update!(:properties, &Map.delete(&1, :token))
    |> Map.update!(:required, &List.delete(&1, :token))
  )
end
