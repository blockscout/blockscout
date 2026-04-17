defmodule BlockScoutWeb.Schemas.API.V2.MUD.TableWithSchema do
  @moduledoc """
  This module defines the schema for the MUD Table with TableSchema struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.MUD.{Table, TableSchema}

  OpenApiSpex.schema(%{
    description: "MUD Table with TableSchema struct.",
    type: :object,
    properties: %{
      table: Table,
      schema: TableSchema
    },
    required: [
      :table,
      :schema
    ],
    nullable: false,
    additionalProperties: false
  })
end
