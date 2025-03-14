defmodule BlockScoutWeb.Schemas.API.V2.ErrorResponses do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule UnprocessableEntityResponse do
    OpenApiSpex.schema(%{
      title: "UnprocessableEntityResponse",
      description: "Response returned when provided parameters are invalid",
      type: :object,
      properties: %{
        message: %Schema{
          type: :string,
          description: "Error message indicating invalid parameters",
          example: "Invalid parameter(s)"
        }
      },
      required: [:message],
      example: %{
        "message" => "Invalid parameter(s)"
      }
    })
  end

  def unprocessable_entity_response do
    {"Unprocessable Entity", "application/json", UnprocessableEntityResponse}
  end
end
