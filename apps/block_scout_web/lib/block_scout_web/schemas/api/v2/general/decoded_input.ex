defmodule BlockScoutWeb.Schemas.API.V2.General.DecodedInput do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      method_id: %Schema{type: :string, nullable: true},
      method_call: %Schema{type: :string, nullable: true},
      parameters: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            name: %Schema{type: :string, nullable: false},
            type: %Schema{type: :string, nullable: false},
            value: %Schema{
              anyOf: [%Schema{type: :object}, %Schema{type: :array}, %Schema{type: :string}],
              nullable: false
            }
          },
          nullable: false,
          additionalProperties: false
        }
      }
    },
    required: [:method_id, :method_call, :parameters],
    nullable: false,
    additionalProperties: false
  })
end
