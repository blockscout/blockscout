defmodule BlockScoutWeb.Schemas.API.V2.Proxy.AccountAbstraction.Status do
  @moduledoc """
  This module defines the schema for the Status struct.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Status struct.",
    type: :object,
    properties: %{
      finished_past_indexing: %Schema{type: :boolean, nullable: false}
    },
    required: [
      :finished_past_indexing
    ],
    additionalProperties: %Schema{
      type: :object,
      properties: %{
        enabled: %Schema{type: :boolean, nullable: false},
        live: %Schema{type: :boolean, nullable: false},
        past_db_logs_indexing_finished: %Schema{type: :boolean, nullable: false},
        past_rpc_logs_indexing_finished: %Schema{type: :boolean, nullable: false}
      },
      additionalProperties: false
    },
    nullable: false
  })
end
