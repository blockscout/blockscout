defmodule Explorer.SmartContract.Solidity.CompilerVersionTest do
  use ExUnit.Case

  doctest Explorer.SmartContract.Solidity.CompilerVersion

  alias Explorer.SmartContract.Solidity.CompilerVersion
  alias Plug.Conn

  describe "fetch_versions" do
    setup do
      bypass = Bypass.open()

      Application.put_env(:explorer, :solc_bin_api_url, "http://localhost:#{bypass.port}")

      {:ok, bypass: bypass}
    end

    test "fetches the list of the solidity compiler versions", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/bin/list.json" == conn.request_path

        Conn.resp(conn, 200, solc_bin_versions())
      end)

      assert {:ok, versions} = CompilerVersion.fetch_versions()
      assert Enum.any?(versions, fn item -> item == "v0.4.9+commit.364da425" end) == true
    end

    test "always returns 'latest' in the first item", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/bin/list.json" == conn.request_path

        Conn.resp(conn, 200, solc_bin_versions())
      end)

      assert {:ok, versions} = CompilerVersion.fetch_versions()
      assert List.first(versions) == "latest"
    end

    test "returns error when list of versions is not available", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Conn.resp(conn, 400, ~S({"error": "bad request"}))
      end)

      assert {:error, "bad request"} = CompilerVersion.fetch_versions()
    end

    test "returns error when there is server error", %{bypass: bypass} do
      Bypass.down(bypass)

      assert {:error, :econnrefused} = CompilerVersion.fetch_versions()
    end
  end

  def solc_bin_versions() do
    File.read!("./test/support/fixture/smart_contract/solc_bin.json")
  end
end
