defmodule Indexer.ENSNameSanitizerTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  require Logger

  alias Indexer.ENSNameSanitizer
  alias Chain
  alias Explorer.Chain.Address

  setup :set_mox_global
  setup :verify_on_exit!

  describe "init/3" do
    test "removes ENS name for address if there is a mismatch", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      ens_unchanged_address = insert(:address, hash: "0x0000000000000000000000000000000000000001")
      insert(:address_name, address: ens_unchanged_address, name: "unchanged.bch", metadata: %{type: "ens"})

      ens_changed_address = insert(:address, hash: "0x069d54a4e31f24AFdD9eB1b53f8319aC83C646c9")
      insert(:address_name, address: ens_changed_address, name: "lns.bch", metadata: %{type: "ens"})

      ens_unset_address = insert(:address, hash: "0x0000000000000000000000000000000000001337")
      insert(:address_name, address: ens_unset_address, name: "lns.bch", metadata: %{type: "ens"})

      normal_address = insert(:address, hash: "0x000000000000000000000000000000000000beef")
      insert(:address_name, address: normal_address, name: "beef")

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        retriever_configuration = Application.get_env(:explorer, Explorer.ENS.NameRetriever)

        Application.put_env(:explorer, Explorer.ENS.NameRetriever,
          enabled: true,
          registry_address: "0xcfb86556760d03942ebf1ba88a9870e67d77b627",
          resolver_address: "0x1ba19b976fefc1c9c684f2b821e494a380f45a0f"
        )

        fetcher_configuration = Application.get_env(:indexer, Indexer.Fetcher.ENSName.Supervisor)

        Application.put_env(:indexer, Indexer.Fetcher.ENSName.Supervisor, disabled?: false)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_call",
                                    params: [
                                      %{
                                        data:
                                          "0x3b3b57de8ec5fe003a78a42b85885934f8e1f35dd17bbaabcb3946c772a02d9c120762ff",
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
               result: "0x0000000000000000000000000000000000000000000000000000000000000001"
             }
           ]}
        end)
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_call",
                                    params: [
                                      %{
                                        data:
                                          "0x3b3b57defa9165a468560cc43085d93d395dd45dee66d76084df5578343b709cf135e074",
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
               result: "0x000000000000000000000000b69d54a4e31f24afdd9eb1b53f8319ac83c646c9"
             }
           ]}
        end)
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_call",
                                    params: [
                                      %{
                                        data:
                                          "0x3b3b57defa9165a468560cc43085d93d395dd45dee66d76084df5578343b709cf135e074",
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
               result: "0x0000000000000000000000000000000000000000000000000000000000000000"
             }
           ]}
        end)

        start_supervised!(
          {ENSNameSanitizer,
           [
             [json_rpc_named_arguments: json_rpc_named_arguments, interval: :timer.seconds(1)],
             [name: :ENSNameSanitizerTest]
           ]}
        )

        Process.sleep(2_000)

        assert !is_nil(Repo.one(from(n in Address.Name, where: n.address_hash == ^ens_unchanged_address.hash)))
        assert is_nil(Repo.one(from(n in Address.Name, where: n.address_hash == ^ens_changed_address.hash)))
        assert is_nil(Repo.one(from(n in Address.Name, where: n.address_hash == ^ens_unset_address.hash)))
        assert !is_nil(Repo.one(from(n in Address.Name, where: n.address_hash == ^normal_address.hash)))

        Application.put_env(:explorer, Explorer.ENS.NameRetriever, retriever_configuration)
        Application.put_env(:indexer, Indexer.Fetcher.ENSName.Supervisor, fetcher_configuration)
      end
    end
  end
end
