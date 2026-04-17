defmodule BlockScoutWeb.Specs do
  @moduledoc """
  Provides utility functions for working with Phoenix router routes in API specification modules.

  This module contains shared functionality used by `BlockScoutWeb.Specs.Public` and
  `BlockScoutWeb.Specs.Private` for route manipulation and processing.
  """

  @doc """
  Retrieves all routes from the given router module and prepends a prefix to each route's path.

  ## Parameters
  - `router`: A Phoenix router module that implements `__routes__/0`.
  - `prefix`: A string to prepend to each route's path.

  ## Returns
  - A list of route maps with the `:path` values modified to include the prefix.
  """
  @spec routes_with_prefix(module(), String.t()) :: [map()]
  def routes_with_prefix(router, prefix) do
    router.__routes__()
    |> Enum.map(fn %{path: path} = route -> %{route | path: prefix <> path} end)
  end
end
