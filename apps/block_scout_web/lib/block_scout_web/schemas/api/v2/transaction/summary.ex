defmodule BlockScoutWeb.Schemas.API.V2.Transaction.Summary do
  @moduledoc """
  This module defines the schema for a transaction summary API response.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  summary_variable_schema = %Schema{
    type: :object,
    required: [:type, :value],
    properties: %{
      type: %Schema{type: :string},
      value: %Schema{
        anyOf: [
          %Schema{type: :string},
          %Schema{type: :number},
          # For address or other complex types
          %Schema{type: :object}
        ]
      }
    },
    additionalProperties: false
  }

  summary_template_variables_schema = %Schema{
    type: :object,
    additionalProperties: summary_variable_schema
  }

  summary_schema = %Schema{
    type: :object,
    required: [:summary_template, :summary_template_variables],
    properties: %{
      summary_template: %Schema{type: :string},
      summary_template_variables: summary_template_variables_schema
    },
    additionalProperties: false
  }

  OpenApiSpex.schema(%{
    type: :object,
    required: [:data, :success],
    properties: %{
      data: %Schema{
        type: :object,
        required: [:summaries],
        properties: %{
          summaries: %Schema{type: :array, items: summary_schema}
        },
        additionalProperties: false
      },
      success: %Schema{type: :boolean}
    },
    additionalProperties: false
  })
end
