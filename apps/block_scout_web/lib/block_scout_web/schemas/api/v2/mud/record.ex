# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.MUD.Record do
  @moduledoc """
  This module defines the schema for the MUD Record struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "MUD Record struct.",
    type: :object,
    properties: %{
      id: General.HexData,
      raw: %Schema{
        type: :object,
        properties: %{
          block_number: General.IntegerString,
          log_index: General.IntegerString,
          dynamic_data: General.HexData,
          encoded_lengths: General.FullHash,
          key0: General.FullHash,
          key1: General.FullHash,
          key_bytes: General.HexData,
          static_data: General.HexData
        },
        nullable: false
      },
      timestamp: General.Timestamp,
      decoded: %Schema{type: :object, nullable: true},
      is_deleted: %Schema{type: :boolean, nullable: false}
    },
    required: [
      :id,
      :raw,
      :timestamp,
      :decoded,
      :is_deleted
    ],
    nullable: false,
    additionalProperties: false
  })
end
