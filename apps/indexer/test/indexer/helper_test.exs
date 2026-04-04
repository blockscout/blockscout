defmodule Indexer.HelperTest do
  use ExUnit.Case, async: true

  alias Indexer.Helper

  describe "json_rpc_named_arguments/1" do
    test "builds expected JSON-RPC named arguments from RPC URL" do
      rpc_url = "https://rpc.example"
      timeout = :timer.minutes(10)

      assert Helper.json_rpc_named_arguments(rpc_url) ==
               [
                 transport: EthereumJSONRPC.HTTP,
                 transport_options: [
                   http: EthereumJSONRPC.HTTP.Tesla,
                   urls: [rpc_url],
                   http_options: [
                     recv_timeout: timeout,
                     timeout: timeout,
                     pool: :ethereum_jsonrpc
                   ]
                 ]
               ]
    end

    test "handles nil RPC URL" do
      assert_raise ArgumentError, "RPC URL must be a non-empty string", fn ->
        Helper.json_rpc_named_arguments(nil)
      end
    end

    test "handles empty string RPC URL" do
      assert_raise ArgumentError, "RPC URL must be a non-empty string", fn ->
        Helper.json_rpc_named_arguments("")
      end
    end

    test "normalizes trailing slash in RPC URL" do
      timeout = :timer.minutes(10)

      assert Helper.json_rpc_named_arguments("https://rpc.example/") ==
               [
                 transport: EthereumJSONRPC.HTTP,
                 transport_options: [
                   http: EthereumJSONRPC.HTTP.Tesla,
                   urls: ["https://rpc.example"],
                   http_options: [
                     recv_timeout: timeout,
                     timeout: timeout,
                     pool: :ethereum_jsonrpc
                   ]
                 ]
               ]
    end
  end
end
