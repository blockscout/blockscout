defmodule BlockScoutWeb.Schemas.API.V2.CSVExport.Response do
  @moduledoc false
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      status: %Schema{type: :string, nullable: false, enum: ["pending", "completed", "failed"]},
      file_id: %Schema{type: :string, nullable: true}
    }
  })
end
