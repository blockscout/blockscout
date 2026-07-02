# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.CSVExport.Response do
  @moduledoc false
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CSVExportResponse",
    type: :object,
    properties: %{
      status: %Schema{type: :string, nullable: false, enum: ["pending", "completed", "failed"]},
      file_id: %Schema{type: :string, nullable: true},
      expires_at: %Schema{type: :string, nullable: true, format: "date-time"}
    },
    required: [:status, :file_id, :expires_at],
    additionalProperties: false
  })
end
