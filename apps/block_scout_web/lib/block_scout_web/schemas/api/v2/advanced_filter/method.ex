defmodule BlockScoutWeb.Schemas.API.V2.AdvancedFilter.Method do
  @moduledoc "Schema for a contract method (id + name pair) returned by the advanced filters methods endpoint."

  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AdvancedFilterMethod",
    description: "Contract method identified by its 4-byte selector and human-readable name.",
    type: :object,
    required: [:method_id, :name],
    properties: %{
      method_id: %Schema{
        type: :string,
        pattern: ~r/^0x[0-9a-f]{8}$/,
        description: "4-byte method selector prefixed with 0x (lowercase hex).",
        example: "0xa9059cbb"
      },
      name: %Schema{
        type: :string,
        description: "Human-readable method name. Empty string if the name could not be resolved.",
        example: "transfer"
      }
    },
    additionalProperties: false
  })
end
