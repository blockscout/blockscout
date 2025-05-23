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

    @spec response() :: {String.t(), String.t(), module()}
    def response do
      {"Unprocessable Entity", "application/json", __MODULE__}
    end
  end

  defmodule ForbiddenResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ForbiddenResponse",
      description: "Response returned when the user is not authorized to access the resource",
      type: :object,
      properties: %{
        message: %Schema{
          type: :string,
          description: "Error message indicating the user is not authorized to access the resource",
          example: "Restricted access"
        }
      }
    })

    @spec response() :: {String.t(), String.t(), module()}
    def response do
      {"Forbidden", "application/json", __MODULE__}
    end
  end
end
