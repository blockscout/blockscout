defmodule Indexer.Fetcher.EnsNameTest do
  require Logger

  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.Token
  alias Indexer.Fetcher.Token, as: TokenFetcher

  alias Explorer.ENS

  setup :verify_on_exit!

  describe "run/3" do
    test "computes namehash", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      # empty name
      assert Base.encode16(ENS.NameRetriever.namehash(""), case: :lower) ==
               "0000000000000000000000000000000000000000000000000000000000000000"

      # top level domain
      assert Base.encode16(ENS.NameRetriever.namehash("bch"), case: :lower) ==
               "4062ae9e99543fadaf6946b98c6f12538a99834a89521ef85301d7d91e281c8d"

      # second level domain
      assert Base.encode16(ENS.NameRetriever.namehash("pat.bch"), case: :lower) ==
               "152641caf3520b1389e875e624d6abec87d7e3c8da6818e62d28686e47b1d378"

      # user registered subdomains
      assert Base.encode16(ENS.NameRetriever.namehash("test.pat.bch"), case: :lower) ==
               "94ce5fc9a82dd35c98bb6fd9a32a88740cb59f646d6060b6805cbb433324ad2b"

      # case insensitivity
      assert Base.encode16(ENS.NameRetriever.namehash("PAT.bch"), case: :lower) ==
               Base.encode16(ENS.NameRetriever.namehash("pat.bch"), case: :lower)

      # malformed name
      assert ENS.NameRetriever.namehash("pat.") == {:error, "Invalid ENS name"}
      # reverse record name chechk
      assert Base.encode16(ENS.NameRetriever.namehash("b69d54a4e31f24afdd9eb1b53f8319ac83c646c9.addr.reverse"),
               case: :lower
             ) == "5af16006ad8cc8ec19f624c12ea9e30511c080ae88071401a57c0e00be6471ca"

      # Logger.warn(Base.encode16(ExKeccak.hash_256("resolver(bytes32)"), case: :lower))
      # Logger.warn(Base.encode16(ExKeccak.hash_256("name(bytes32)"), case: :lower))
      # Logger.warn(Base.encode16(ExKeccak.hash_256("addr(bytes32)"), case: :lower))
    end

    test "ENS disabled test", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      configuration = Application.get_env(:explorer, Explorer.ENS.NameRetriever)

      Application.put_env(:explorer, Explorer.ENS.NameRetriever,
        enabled: false,
        registry_address: "0xcfb86556760d03942ebf1ba88a9870e67d77b627"
      )

      assert {:error, "ENS support was not enabled"} ==
               ENS.NameRetriever.fetch_name_of("0xb69d54a4e31f24AFdD9eB1b53f8319aC83C646c9")

      Application.put_env(:explorer, Explorer.ENS.NameRetriever, configuration)
    end

    test "fetches ENS name from address using registry", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        configuration = Application.get_env(:explorer, Explorer.ENS.NameRetriever)

        Application.put_env(:explorer, Explorer.ENS.NameRetriever,
          enabled: true,
          registry_address: "0xcfb86556760d03942ebf1ba88a9870e67d77b627",
          resolver_address: nil
        )

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_call",
                                    params: [
                                      %{
                                        data:
                                          "0x0178b8bf5af16006ad8cc8ec19f624c12ea9e30511c080ae88071401a57c0e00be6471ca",
                                        to: "0xcfb86556760d03942ebf1ba88a9870e67d77b627"
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
               result: "0x0000000000000000000000001ba19b976fefc1c9c684f2b821e494a380f45a0f"
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
           ]}
        end)

        assert {:ok, "lns.bch"} ==
                 ENS.NameRetriever.fetch_name_of("0xb69d54a4e31f24AFdD9eB1b53f8319aC83C646c9")

        Application.put_env(:explorer, Explorer.ENS.NameRetriever, configuration)
      end
    end

    test "fetches ENS name from address using resolver", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        configuration = Application.get_env(:explorer, Explorer.ENS.NameRetriever)

        Application.put_env(:explorer, Explorer.ENS.NameRetriever,
          enabled: true,
          registry_address: "0xcfb86556760d03942ebf1ba88a9870e67d77b627",
          resolver_address: "0x1ba19b976fefc1c9c684f2b821e494a380f45a0f"
        )

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
           ]}
        end)

        assert {:ok, "lns.bch"} ==
                 ENS.NameRetriever.fetch_name_of("0xb69d54a4e31f24AFdD9eB1b53f8319aC83C646c9")

        Application.put_env(:explorer, Explorer.ENS.NameRetriever, configuration)
      end
    end

    test "fetches ENS address from name using resolver", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        configuration = Application.get_env(:explorer, Explorer.ENS.NameRetriever)

        Application.put_env(:explorer, Explorer.ENS.NameRetriever,
          enabled: true,
          registry_address: "0xcfb86556760d03942ebf1ba88a9870e67d77b627",
          resolver_address: "0x1ba19b976fefc1c9c684f2b821e494a380f45a0f"
        )

        EthereumJSONRPC.Mox
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

        assert {:ok, "0xb69d54a4e31f24afdd9eb1b53f8319ac83c646c9"} ==
                 ENS.NameRetriever.fetch_address_of("lns.bch")

        Application.put_env(:explorer, Explorer.ENS.NameRetriever, configuration)
      end
    end
  end
end
