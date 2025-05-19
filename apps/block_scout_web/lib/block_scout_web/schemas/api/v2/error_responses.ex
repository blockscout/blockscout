defmodule BlockScoutWeb.Schemas.API.V2.ErrorResponses do
  @moduledoc """
  This module contains the schemas for the error responses.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  defmodule UnprocessableEntityResponse do
    @moduledoc false
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

  @doc """
  Returns the response tuple for unprocessable entity errors.

  ## Returns

  - A tuple containing the status description, content type, and response schema.
  """
  @spec unprocessable_entity_response() :: {String.t(), String.t(), module()}
  def unprocessable_entity_response do
    {"Unprocessable Entity", "application/json", UnprocessableEntityResponse}
  end
end
