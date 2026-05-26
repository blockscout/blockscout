# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Specs.PublicLegacyTagTest do
  use ExUnit.Case, async: true

  @legacy_paths [
    {:get, "/api/legacy/logs/get-logs"},
    {:get, "/api/legacy/block/get-block-number-by-time"},
    {:get, "/api/legacy/block/eth-block-number"},
    {:post, "/api/legacy/eth/eth-call"},
    {:post, "/api/legacy/eth/eth-get-balance"},
    {:post, "/api/legacy/eth/eth-get-storage-at"},
    {:post, "/api/legacy/eth/eth-send-raw-transaction"}
  ]

  setup_all do
    {:ok, spec: BlockScoutWeb.Specs.Public.spec()}
  end

  for {method, path} <- @legacy_paths do
    describe "#{String.upcase(to_string(method))} #{path}" do
      test "path exists in spec.paths", %{spec: spec} do
        path = unquote(path)
        assert Map.has_key?(spec.paths, path), "Expected path #{path} to be present in spec.paths"
      end

      test "operation carries tags: [\"legacy\"]", %{spec: spec} do
        path = unquote(path)
        method = unquote(method)
        operation = operation_for(spec, path, method)

        assert operation != nil, "Expected a #{method} operation for #{path}"
        assert operation.tags == ["legacy"], "Expected tags [\"legacy\"] on #{path}, got: #{inspect(operation.tags)}"
      end

      test "operation has a declared 200 response", %{spec: spec} do
        path = unquote(path)
        method = unquote(method)
        operation = operation_for(spec, path, method)

        assert operation != nil, "Expected a #{method} operation for #{path}"

        response = Map.get(operation.responses, "200") || Map.get(operation.responses, 200)

        assert response != nil,
               "Expected a 200 response on #{path}, got keys: #{inspect(Map.keys(operation.responses))}"
      end

      test "200 response has an application/json schema", %{spec: spec} do
        path = unquote(path)
        method = unquote(method)
        operation = operation_for(spec, path, method)

        assert operation != nil, "Expected a #{method} operation for #{path}"

        response = Map.get(operation.responses, "200") || Map.get(operation.responses, 200)
        assert response != nil, "Expected a 200 response on #{path}"

        schema = get_in(response, [Access.key!(:content), "application/json", Access.key!(:schema)])
        assert schema != nil, "Expected an application/json schema in the 200 response of #{path}"
      end
    end
  end

  defp operation_for(spec, path, method) do
    path_item = Map.fetch!(spec.paths, path)
    Map.get(path_item, method)
  end
end
