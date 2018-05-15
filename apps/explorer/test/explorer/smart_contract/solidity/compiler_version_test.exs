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

    test "fetches the list of the solidity compiler versions", %{ bypass: bypass } do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/bin/list.json" == conn.request_path

        Conn.resp(conn, 200, solc_bin_versions())
      end)

      assert {:ok, versions} = CompilerVersion.fetch_versions()
      assert Enum.any?(versions, fn (item) -> item == {"0.4.9", "0.4.9"} end) == true
    end
  end

  def solc_bin_versions() do
    File.read!("./test/support/fixture/smart_contract/solc_bin.json")
  end
end
