defmodule BlockScoutWeb.GraphQL.Middleware.ApiEnabled do
  @moduledoc """
  Middleware to check if the GraphQL API is enabled.
  """
  alias Absinthe.Resolution

  @behaviour Absinthe.Middleware

  @api_is_disabled "GraphQL API is disabled."

  def call(resolution, _config) do
    if resolution.context.api_enabled do
      resolution
    else
      resolution
      |> Resolution.put_result({:error, @api_is_disabled})
    end
  end
end
