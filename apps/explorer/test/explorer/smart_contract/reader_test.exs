defmodule Explorer.SmartContract.ReaderTest do
  use ExUnit.Case, async: true
  use Explorer.DataCase

  doctest Explorer.SmartContract.Reader

  alias Explorer.SmartContract.Reader
  alias Plug.Conn
  alias Explorer.Chain.Hash

  @ethereum_jsonrpc_original Application.get_env(:ethereum_jsonrpc, :url)

  describe "query_contract/2" do
    setup do
      bypass = Bypass.open()

      Application.put_env(:ethereum_jsonrpc, :url, "http://localhost:#{bypass.port}")

      on_exit(fn ->
        Application.put_env(:ethereum_jsonrpc, :url, @ethereum_jsonrpc_original)
      end)

      {:ok, bypass: bypass}
    end

    test "correctly returns the result of a smart contract function", %{bypass: bypass} do
      blockchain_resp =
        "[{\"jsonrpc\":\"2.0\",\"result\":\"0x0000000000000000000000000000000000000000000000000000000000000000\",\"id\":\"get\"}]\n"

      Bypass.expect(bypass, fn conn -> Conn.resp(conn, 200, blockchain_resp) end)

      hash =
        :smart_contract
        |> insert()
        |> Map.get(:address_hash)
        |> Hash.to_string()

      assert Reader.query_contract(hash, %{"get" => []}) == %{"get" => [0]}
    end
  end

  describe "setup_call_payload/2" do
    test "returns the expected payload" do
      function_name = "get"
      contract_address = "0x123789abc"
      data = "0x6d4ce63c"

      assert Reader.setup_call_payload(
               {function_name, data},
               contract_address
             ) == %{contract_address: "0x123789abc", data: "0x6d4ce63c", id: "get"}
    end
  end
end
