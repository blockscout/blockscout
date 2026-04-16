defmodule BlockScoutWeb.Specs.PublicLegacyTagTest do
  use ExUnit.Case, async: true

  @legacy_paths [
    "/legacy/logs/get-logs",
    "/legacy/block/get-block-number-by-time",
    "/legacy/block/eth-block-number"
  ]

  setup_all do
    {:ok, spec: BlockScoutWeb.Specs.Public.spec()}
  end

  for path <- @legacy_paths do
    describe "path #{path}" do
      test "exists in spec.paths", %{spec: spec} do
        path = unquote(path)
        assert Map.has_key?(spec.paths, path), "Expected path #{path} to be present in spec.paths"
      end

      test "GET operation carries tags: [\"legacy\"]", %{spec: spec} do
        path = unquote(path)
        path_item = Map.fetch!(spec.paths, path)
        operation = path_item.get

        assert operation != nil, "Expected a GET operation for #{path}"
        assert operation.tags == ["legacy"], "Expected tags [\"legacy\"] on #{path}, got: #{inspect(operation.tags)}"
      end

      test "GET operation has a declared 200 response", %{spec: spec} do
        path = unquote(path)
        path_item = Map.fetch!(spec.paths, path)
        operation = path_item.get

        assert operation != nil, "Expected a GET operation for #{path}"

        response = Map.get(operation.responses, "200") || Map.get(operation.responses, 200)

        assert response != nil,
               "Expected a 200 response on #{path}, got keys: #{inspect(Map.keys(operation.responses))}"
      end

      test "GET 200 response has an application/json schema", %{spec: spec} do
        path = unquote(path)
        path_item = Map.fetch!(spec.paths, path)
        operation = path_item.get

        assert operation != nil, "Expected a GET operation for #{path}"

        response = Map.get(operation.responses, "200") || Map.get(operation.responses, 200)
        assert response != nil, "Expected a 200 response on #{path}"

        schema = get_in(response, [Access.key!(:content), "application/json", Access.key!(:schema)])
        assert schema != nil, "Expected an application/json schema in the 200 response of #{path}"
      end
    end
  end
end
