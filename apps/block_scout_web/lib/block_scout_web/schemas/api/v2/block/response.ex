defmodule BlockScoutWeb.Schemas.API.V2.Block.Response do
  @moduledoc """
  This module defines the schema for block response from /api/v2/blocks/:hash_or_number.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Block
  alias BlockScoutWeb.Schemas.API.V2.Block.Common
  alias BlockScoutWeb.Schemas.Helper

  OpenApiSpex.schema(
    Block.schema()
    |> Helper.extend_schema(
      title: "BlockResponse",
      description: "Block response",
      properties: %{rewards: Common.rewards_schema_single_block()}
    )
  )
end
