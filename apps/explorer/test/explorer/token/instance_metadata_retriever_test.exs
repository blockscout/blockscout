defmodule Explorer.Token.InstanceMetadataRetrieverTest do
  use EthereumJSONRPC.Case

  alias Explorer.Token.InstanceMetadataRetriever

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  describe "fetch_metadata/2" do
    @tag :no_parity
    @tag :no_geth
    test "fetches json metadata", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_call",
                                    params: [
                                      %{
                                        data:
                                          "0xc87b56dd000000000000000000000000000000000000000000000000fdd5b9fa9d4bfb20",
                                        to: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"
                                      },
                                      "latest"
                                    ]
                                  }
                                ],
                                _options ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result:
                 "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003568747470733a2f2f7661756c742e7761727269646572732e636f6d2f31383239303732393934373636373130323439362e6a736f6e0000000000000000000000"
             }
           ]}
        end)
      end

      assert %{
               "tokenURI" => {:ok, ["https://vault.warriders.com/18290729947667102496.json"]}
             } ==
               InstanceMetadataRetriever.query_contract("0x5caebd3b32e210e85ce3e9d51638b9c445481567", %{
                 "tokenURI" => [18_290_729_947_667_102_496]
               })
    end
  end
end
