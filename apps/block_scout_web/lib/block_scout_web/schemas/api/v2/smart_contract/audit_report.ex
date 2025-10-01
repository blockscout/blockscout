defmodule BlockScoutWeb.Schemas.API.V2.SmartContract.AuditReport do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Smart contract audit report item",
    type: :object,
    properties: %{
      audit_company_name: %Schema{type: :string, nullable: true},
      audit_publish_date: %Schema{type: :string, format: :date, nullable: true},
      audit_report_url: %Schema{type: :string, nullable: true}
    }
  })
end
