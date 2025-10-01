defmodule BlockScoutWeb.Schemas.API.V2.ErrorResponses do
  @moduledoc """
  This module contains the schemas for the error responses.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

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
      },
      additionalProperties: false
    })

    @spec response() :: {String.t(), String.t(), module()}
    def response do
      {"Forbidden", "application/json", __MODULE__}
    end
  end

  defmodule NotFoundResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "NotFoundResponse",
      description: "Response returned when the requested resource is not found",
      type: :object,
      properties: %{
        message: %Schema{
          type: :string,
          description: "Error message indicating the requested resource was not found",
          example: "Resource not found"
        }
      }
    })

    @spec response() :: {String.t(), String.t(), module()}
    def response do
      {"Not Found", "application/json", __MODULE__}
    end
  end
end
