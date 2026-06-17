# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.SmartContract.AuditReport do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Smart contract audit report item",
    type: :object,
    properties: %{
      audit_company_name: %Schema{type: :string},
      audit_publish_date: %Schema{type: :string, format: :date},
      audit_report_url: %Schema{type: :string}
    },
    required: [:audit_company_name, :audit_publish_date, :audit_report_url]
  })
end
