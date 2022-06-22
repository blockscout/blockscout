defmodule Indexer.Fetcher.TokenTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  require Logger

  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Indexer.Fetcher.ENSName, as: ENSNameFetcher
  setup :verify_on_exit!

  describe "init/3" do
    test "returns address hashes for ens name lookup", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert ENSNameFetcher.init([], &[&1 | &2], json_rpc_named_arguments) == []

      %Address{hash: hash} = insert(:address)

      assert ENSNameFetcher.init([], &[&1 | &2], json_rpc_named_arguments) == [hash]
    end
  end

  describe "run/3" do
    test "inserts ENS name for address with ENSName fetcher", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %Address{hash: hash} = insert(:address, hash: "0xb69d54a4e31f24AFdD9eB1b53f8319aC83C646c9")

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        configuration = Application.get_env(:explorer, Explorer.ENS.NameRetriever)
        Application.put_env(:explorer, Explorer.ENS.NameRetriever, [enabled: true, registry_address: "0xcfb86556760d03942ebf1ba88a9870e67d77b627", resolver_address: "0x1ba19b976fefc1c9c684f2b821e494a380f45a0f"])

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_call",
                                    params: [
                                      %{
                                        data:
                                          "0x691f34315af16006ad8cc8ec19f624c12ea9e30511c080ae88071401a57c0e00be6471ca",
                                        to: "0x1ba19b976fefc1c9c684f2b821e494a380f45a0f"
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
                  "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000076c6e732e62636800000000000000000000000000000000000000000000000000"
              }
            ]
          }
        end)

        assert ENSNameFetcher.run([hash], json_rpc_named_arguments) == :ok

        {:ok, address} = Chain.hash_to_address(hash)
        name = Enum.at(address.names, 0)
        assert name.name == "lns.bch"

        Application.put_env(:explorer, Explorer.ENS.NameRetriever, configuration)
      end
    end
  end
end
