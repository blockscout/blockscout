defmodule BlockScoutWeb.Schemas.API.V2.MUD.Table do
  @moduledoc """
  This module defines the schema for the MUD Table struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "MUD Table struct.",
    type: :object,
    properties: %{
      table_id: General.FullHash,
      table_full_name: %Schema{type: :string, nullable: false},
      table_type: %Schema{type: :string, enum: ["offchain", "onchain", "unknown"], nullable: false},
      table_namespace: %Schema{type: :string, nullable: false},
      table_name: %Schema{type: :string, nullable: false}
    },
    required: [
      :table_id,
      :table_full_name,
      :table_type,
      :table_namespace,
      :table_name
    ],
    nullable: false,
    additionalProperties: false
  })
end
