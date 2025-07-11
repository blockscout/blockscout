defmodule Explorer.SmartContract.CompilerVersionTest do
  use ExUnit.Case

  doctest Explorer.SmartContract.CompilerVersion

  alias Explorer.SmartContract.CompilerVersion
  alias Plug.Conn

  setup do
    configuration = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)
    Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, enabled: false)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, configuration)
    end)
  end

  describe "fetch_versions/1" do
    setup do
      bypass = Bypass.open()

      on_exit(fn ->
        Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
      end)

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)
      Application.put_env(:explorer, :solc_bin_api_url, "http://localhost:#{bypass.port}")

      {:ok, bypass: bypass}
    end

    test "fetches the list of the solidity compiler versions", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/bin/list.json" == conn.request_path

        Conn.resp(conn, 200, solc_bin_versions())
      end)

      assert {:ok, versions} = CompilerVersion.fetch_versions(:solc)
      assert Enum.any?(versions, fn item -> item == "v0.4.9+commit.364da425" end) == true
    end

    test "always returns 'latest' in the first item", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/bin/list.json" == conn.request_path

        Conn.resp(conn, 200, solc_bin_versions())
      end)

      assert {:ok, versions} = CompilerVersion.fetch_versions(:solc)
      assert List.first(versions) == "latest"
    end

    test "returns error when list of versions is not available", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Conn.resp(conn, 400, ~S({"error": "bad request"}))
      end)

      assert {:error, "bad request"} = CompilerVersion.fetch_versions(:solc)
    end

    test "returns error when there is server error", %{bypass: bypass} do
      Bypass.down(bypass)

      assert {:error, %{reason: :econnrefused}} = CompilerVersion.fetch_versions(:solc)
    end
  end

  def solc_bin_versions() do
    File.read!("./test/support/fixture/smart_contract/solc_bin.json")
  end
end
