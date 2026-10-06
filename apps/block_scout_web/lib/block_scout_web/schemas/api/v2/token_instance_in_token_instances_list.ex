# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.TokenInstanceInTokenInstancesList do
  @moduledoc """
  This module defines the schema for a token instance item returned by the
  `GET /api/v2/tokens/:address_hash/instances` endpoint. Unlike TokenInstanceInList,
  the `token` field is omitted because all items belong to the same token contract.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{General, Token.Type, TokenInstance}
  alias BlockScoutWeb.Schemas.Helper

  OpenApiSpex.schema(
    TokenInstance.schema()
    |> Helper.extend_schema(
      title: "TokenInstanceInTokenInstancesList",
      # token_type and value are present on the holder-filtered path but absent on
      # the unfiltered path, so they are allowed but not required.
      properties: %{
        token_type: Type,
        value: General.IntegerStringNullable
      }
    )
    |> Map.update!(:properties, &Map.delete(&1, :token))
    |> Map.update!(:required, &List.delete(&1, :token))
  )
end
