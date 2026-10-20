# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Routers.ApiRouterPipelinesTest do
  @moduledoc """
  Guards the pipeline assignment of routes in `BlockScoutWeb.Routers.ApiRouter`.

  `Phoenix.ConnTest` skips CSRF checks, so a request test cannot notice that a
  non-GET route runs through a pipeline with `:protect_from_forgery`. API
  clients send no CSRF token, and such a route returns 403 to all of them (see
  issue #14878). This test checks the router definition instead.
  """

  use ExUnit.Case, async: true

  use Utils.CompileTimeEnvHelper,
    reading_enabled: [:block_scout_web, [BlockScoutWeb.Routers.ApiRouter, :reading_enabled]]

  alias BlockScoutWeb.Routers.ApiRouter

  @csrf_protected_pipelines [:api_v2, :api_v2_csv]

  test "no non-GET route goes through a CSRF-protected pipeline" do
    offending =
      routes_with_pipelines()
      |> Enum.filter(fn {route, _pipelines} -> route.verb != :get end)
      |> Enum.filter(fn {_route, pipelines} -> Enum.any?(pipelines, &(&1 in @csrf_protected_pipelines)) end)
      |> Enum.map(fn {route, pipelines} -> {route.verb, route.path, pipelines} end)

    assert offending == [],
           "Non-GET routes on a pipeline with :protect_from_forgery return 403 to API clients: #{inspect(offending)}"
  end

  # The /legacy routes are compiled only when API_V1_READ_METHODS_DISABLED is
  # not `true`.
  if @reading_enabled do
    test "all /legacy routes go through :api_v2_no_session" do
      legacy_routes =
        Enum.filter(routes_with_pipelines(), fn {route, _pipelines} -> String.starts_with?(route.path, "/legacy") end)

      assert legacy_routes != [], "Expected /legacy routes to be compiled"

      for {route, pipelines} <- legacy_routes do
        assert pipelines == [:api_v2_no_session],
               "Expected #{route.verb} #{route.path} to use :api_v2_no_session, got: #{inspect(pipelines)}"
      end
    end
  end

  # `__routes__/0` does not carry the pipelines in this Phoenix version, so the
  # pipelines are read through `Phoenix.Router.route_info/4` for a concrete
  # path that matches each route. `forward` entries carry the verb `:*` and
  # delegate to another router with its own pipelines, so they are skipped.
  defp routes_with_pipelines do
    ApiRouter.__routes__()
    |> Enum.reject(&(&1.verb == :*))
    |> Enum.map(fn route ->
      method = route.verb |> to_string() |> String.upcase()
      info = Phoenix.Router.route_info(ApiRouter, method, concrete_path(route.path), "")

      assert %{route: matched_path, pipe_through: pipelines} = info,
             "Expected #{method} #{route.path} to be routable, got: #{inspect(info)}"

      assert matched_path == route.path,
             "Expected #{method} #{route.path} to match itself, but #{matched_path} matched first"

      {route, pipelines}
    end)
  end

  # Replaces `:param` and `*glob` segments with a literal so that the path is
  # matched by the router.
  defp concrete_path(path) do
    path
    |> String.split("/")
    |> Enum.map_join("/", fn
      ":" <> _ -> "x"
      "*" <> _ -> "x"
      segment -> segment
    end)
  end
end
