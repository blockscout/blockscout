defmodule Explorer.Chain.SmartContract.ProxyTest do
  use Explorer.DataCase, async: false
  import Mox
  alias Explorer.Chain.SmartContract
  alias Explorer.Chain.SmartContract.Proxy

  setup :verify_on_exit!
  setup :set_mox_global

  describe "proxy contracts features" do
    @proxy_abi [
      %{
        "type" => "function",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "outputs" => [%{"type" => "bool", "name" => ""}],
        "name" => "upgradeTo",
        "inputs" => [%{"type" => "address", "name" => "newImplementation"}],
        "constant" => false
      },
      %{
        "type" => "function",
        "stateMutability" => "view",
        "payable" => false,
        "outputs" => [%{"type" => "uint256", "name" => ""}],
        "name" => "version",
        "inputs" => [],
        "constant" => true
      },
      %{
        "type" => "function",
        "stateMutability" => "view",
        "payable" => false,
        "outputs" => [%{"type" => "address", "name" => ""}],
        "name" => "implementation",
        "inputs" => [],
        "constant" => true
      },
      %{
        "type" => "function",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "outputs" => [],
        "name" => "renounceOwnership",
        "inputs" => [],
        "constant" => false
      },
      %{
        "type" => "function",
        "stateMutability" => "view",
        "payable" => false,
        "outputs" => [%{"type" => "address", "name" => ""}],
        "name" => "getOwner",
        "inputs" => [],
        "constant" => true
      },
      %{
        "type" => "function",
        "stateMutability" => "view",
        "payable" => false,
        "outputs" => [%{"type" => "address", "name" => ""}],
        "name" => "getProxyStorage",
        "inputs" => [],
        "constant" => true
      },
      %{
        "type" => "function",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "outputs" => [],
        "name" => "transferOwnership",
        "inputs" => [%{"type" => "address", "name" => "_newOwner"}],
        "constant" => false
      },
      %{
        "type" => "constructor",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "inputs" => [
          %{"type" => "address", "name" => "_proxyStorage"},
          %{"type" => "address", "name" => "_implementationAddress"}
        ]
      },
      %{"type" => "fallback", "stateMutability" => "nonpayable", "payable" => false},
      %{
        "type" => "event",
        "name" => "Upgraded",
        "inputs" => [
          %{"type" => "uint256", "name" => "version", "indexed" => false},
          %{"type" => "address", "name" => "implementation", "indexed" => true}
        ],
        "anonymous" => false
      },
      %{
        "type" => "event",
        "name" => "OwnershipRenounced",
        "inputs" => [%{"type" => "address", "name" => "previousOwner", "indexed" => true}],
        "anonymous" => false
      },
      %{
        "type" => "event",
        "name" => "OwnershipTransferred",
        "inputs" => [
          %{"type" => "address", "name" => "previousOwner", "indexed" => true},
          %{"type" => "address", "name" => "newOwner", "indexed" => true}
        ],
        "anonymous" => false
      }
    ]

    @implementation_abi [
      %{
        "constant" => false,
        "inputs" => [%{"name" => "x", "type" => "uint256"}],
        "name" => "set",
        "outputs" => [],
        "payable" => false,
        "stateMutability" => "nonpayable",
        "type" => "function"
      },
      %{
        "constant" => true,
        "inputs" => [],
        "name" => "get",
        "outputs" => [%{"name" => "", "type" => "uint256"}],
        "payable" => false,
        "stateMutability" => "view",
        "type" => "function"
      }
    ]

    # EIP-1967 + EIP-1822
    defp request_zero_implementations do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn %{
                                id: 0,
                                method: "eth_getStorageAt",
                                params: [
                                  _,
                                  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                  "latest"
                                ]
                              },
                              _options ->
        {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
      end)
      |> expect(:json_rpc, fn %{
                                id: 0,
                                method: "eth_getStorageAt",
                                params: [
                                  _,
                                  "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
                                  "latest"
                                ]
                              },
                              _options ->
        {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
      end)
      |> expect(:json_rpc, fn %{
                                id: 0,
                                method: "eth_getStorageAt",
                                params: [
                                  _,
                                  "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3",
                                  "latest"
                                ]
                              },
                              _options ->
        {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
      end)
      |> expect(:json_rpc, fn %{
                                id: 0,
                                method: "eth_getStorageAt",
                                params: [
                                  _,
                                  "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7",
                                  "latest"
                                ]
                              },
                              _options ->
        {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
      end)
    end

    test "combine_proxy_implementation_abi/2 returns empty [] abi if proxy abi is null" do
      proxy_contract_address = insert(:contract_address)

      assert Proxy.combine_proxy_implementation_abi(%SmartContract{address_hash: proxy_contract_address.hash, abi: nil}) ==
               []
    end

    test "combine_proxy_implementation_abi/2 returns [] abi for unverified proxy" do
      proxy_contract_address = insert(:contract_address)

      smart_contract =
        insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: [], contract_code_md5: "123")

      request_zero_implementations()

      assert Proxy.combine_proxy_implementation_abi(smart_contract) == []
    end

    test "combine_proxy_implementation_abi/2 returns proxy abi if implementation is not verified" do
      proxy_contract_address = insert(:contract_address)

      smart_contract =
        insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: @proxy_abi, contract_code_md5: "123")

      assert Proxy.combine_proxy_implementation_abi(smart_contract) == @proxy_abi
    end

    test "combine_proxy_implementation_abi/2 returns proxy + implementation abi if implementation is verified" do
      proxy_contract_address = insert(:contract_address)

      smart_contract =
        insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: @proxy_abi, contract_code_md5: "123")

      implementation_contract_address = insert(:contract_address)

      insert(:smart_contract,
        address_hash: implementation_contract_address.hash,
        abi: @implementation_abi,
        contract_code_md5: "123"
      )

      implementation_contract_address_hash_string =
        Base.encode16(implementation_contract_address.hash.bytes, case: :lower)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: _, params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x000000000000000000000000" <> implementation_contract_address_hash_string
             }
           ]}
        end
      )

      combined_abi = Proxy.combine_proxy_implementation_abi(smart_contract)

      assert Enum.any?(@proxy_abi, fn el -> el == Enum.at(@implementation_abi, 0) end) == false
      assert Enum.any?(@proxy_abi, fn el -> el == Enum.at(@implementation_abi, 1) end) == false
      assert Enum.any?(combined_abi, fn el -> el == Enum.at(@implementation_abi, 0) end) == true
      assert Enum.any?(combined_abi, fn el -> el == Enum.at(@implementation_abi, 1) end) == true
    end

    test "get_implementation_abi_from_proxy/2 returns empty [] abi if proxy abi is null" do
      proxy_contract_address = insert(:contract_address)

      assert Proxy.get_implementation_abi_from_proxy(
               %SmartContract{address_hash: proxy_contract_address.hash, abi: nil},
               []
             ) ==
               []
    end

    test "get_implementation_abi_from_proxy/2 returns [] abi for unverified proxy" do
      proxy_contract_address = insert(:contract_address)

      smart_contract =
        insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: [], contract_code_md5: "123")

      request_zero_implementations()

      assert Proxy.combine_proxy_implementation_abi(smart_contract) == []
    end

    test "get_implementation_abi_from_proxy/2 returns [] if implementation is not verified" do
      proxy_contract_address = insert(:contract_address)

      smart_contract =
        insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: @proxy_abi, contract_code_md5: "123")

      assert Proxy.get_implementation_abi_from_proxy(smart_contract, []) == []
    end

    test "get_implementation_abi_from_proxy/2 returns implementation abi if implementation is verified" do
      proxy_contract_address = insert(:contract_address)

      smart_contract =
        insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: @proxy_abi, contract_code_md5: "123")

      implementation_contract_address = insert(:contract_address)

      insert(:smart_contract,
        address_hash: implementation_contract_address.hash,
        abi: @implementation_abi,
        contract_code_md5: "123"
      )

      implementation_contract_address_hash_string =
        Base.encode16(implementation_contract_address.hash.bytes, case: :lower)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: _, params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x000000000000000000000000" <> implementation_contract_address_hash_string
             }
           ]}
        end
      )

      implementation_abi = Proxy.get_implementation_abi_from_proxy(smart_contract, [])

      assert implementation_abi == @implementation_abi
    end

    test "get_implementation_abi_from_proxy/2 returns implementation abi in case of EIP-1967 proxy pattern" do
      proxy_contract_address = insert(:contract_address)

      smart_contract =
        insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: [], contract_code_md5: "123")

      implementation_contract_address = insert(:contract_address)

      insert(:smart_contract,
        address_hash: implementation_contract_address.hash,
        abi: @implementation_abi,
        contract_code_md5: "123"
      )

      implementation_contract_address_hash_string =
        Base.encode16(implementation_contract_address.hash.bytes, case: :lower)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn %{
             id: _id,
             method: "eth_getStorageAt",
             params: [
               _,
               "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
               "latest"
             ]
           },
           _options ->
          {:ok, "0x000000000000000000000000" <> implementation_contract_address_hash_string}
        end
      )

      implementation_abi = Proxy.get_implementation_abi_from_proxy(smart_contract, [])

      assert implementation_abi == @implementation_abi
    end
  end
end
