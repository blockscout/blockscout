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
      id: General.HexString,
      raw: %Schema{
        type: :object,
        properties: %{
          block_number: General.IntegerString,
          log_index: General.IntegerString,
          dynamic_data: General.HexString,
          encoded_lengths: General.FullHash,
          key0: General.FullHash,
          key1: General.FullHash,
          key_bytes: General.HexString,
          static_data: General.HexString
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
