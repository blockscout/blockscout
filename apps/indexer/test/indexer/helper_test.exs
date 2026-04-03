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
  end
end
