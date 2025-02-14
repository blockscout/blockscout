defmodule Explorer.Chain.SmartContract.ProxyTest do
  use Explorer.DataCase, async: false
  import Mox
  alias Explorer.Chain.SmartContract
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.TestHelper

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

    test "combine_proxy_implementation_abi/2 returns empty [] abi if proxy abi is null" do
      proxy_contract_address = insert(:contract_address)

      assert Proxy.combine_proxy_implementation_abi(%SmartContract{address_hash: proxy_contract_address.hash, abi: nil}) ==
               []
    end

    test "combine_proxy_implementation_abi/2 returns [] abi for unverified proxy" do
      TestHelper.get_all_proxies_implementation_zero_addresses()

      proxy_contract_address = insert(:contract_address)

      smart_contract =
        insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: [], contract_code_md5: "123")

      assert Proxy.combine_proxy_implementation_abi(smart_contract) == []
    end

    test "combine_proxy_implementation_abi/2 returns proxy abi if implementation is not verified" do
      TestHelper.get_all_proxies_implementation_zero_addresses()

      proxy_contract_address = insert(:contract_address)

      smart_contract =
        insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: @proxy_abi, contract_code_md5: "123")

      assert Proxy.combine_proxy_implementation_abi(smart_contract) == @proxy_abi
    end

    test "combine_proxy_implementation_abi/2 returns proxy + implementation abi if implementation is verified" do
      proxy_contract_address = insert(:contract_address)

      proxy_smart_contract =
        insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: @proxy_abi, contract_code_md5: "123")

      implementation_contract_address = insert(:contract_address)

      implementation_smart_contract =
        insert(:smart_contract,
          address_hash: implementation_contract_address.hash,
          abi: @implementation_abi,
          contract_code_md5: "123",
          name: "impl"
        )

      insert(:proxy_implementation,
        proxy_address_hash: proxy_contract_address.hash,
        proxy_type: "eip1167",
        address_hashes: [implementation_contract_address.hash],
        names: [implementation_smart_contract.name]
      )

      combined_abi = Proxy.combine_proxy_implementation_abi(proxy_smart_contract)

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

    test "get_implementation_abi_from_proxy/2 returns [] if implementation is not verified" do
      proxy_contract_address = insert(:contract_address)

      smart_contract =
        insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: @proxy_abi, contract_code_md5: "123")

      TestHelper.get_all_proxies_implementation_zero_addresses()

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

      TestHelper.get_all_proxies_implementation_zero_addresses()

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

    test "get_implementation_abi_from_proxy/2 returns implementation abi in case of EIP-1967 proxy pattern (logic contract)" do
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

      response = "0x000000000000000000000000" <> implementation_contract_address_hash_string

      EthereumJSONRPC.Mox
      |> TestHelper.mock_logic_storage_pointer_request(false, response)

      implementation_abi = Proxy.get_implementation_abi_from_proxy(smart_contract, [])

      assert implementation_abi == @implementation_abi
    end
  end

  @beacon_abi [
    %{
      "type" => "function",
      "stateMutability" => "view",
      "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
      "name" => "implementation",
      "inputs" => []
    }
  ]
  test "get_implementation_abi_from_proxy/2 returns implementation abi in case of EIP-1967 proxy pattern (beacon contract)" do
    proxy_contract_address = insert(:contract_address)

    smart_contract =
      insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: [], contract_code_md5: "123")

    beacon_contract_address = insert(:contract_address)

    insert(:smart_contract,
      address_hash: beacon_contract_address.hash,
      abi: @beacon_abi,
      contract_code_md5: "123"
    )

    beacon_contract_address_hash_string = Base.encode16(beacon_contract_address.hash.bytes, case: :lower)

    implementation_contract_address = insert(:contract_address)

    insert(:smart_contract,
      address_hash: implementation_contract_address.hash,
      abi: @implementation_abi,
      contract_code_md5: "123"
    )

    implementation_contract_address_hash_string =
      Base.encode16(implementation_contract_address.hash.bytes, case: :lower)

    eip_1967_beacon_proxy_mock_requests(
      beacon_contract_address_hash_string,
      implementation_contract_address_hash_string,
      :full_32
    )

    implementation_abi = Proxy.get_implementation_abi_from_proxy(smart_contract, [])
    verify!(EthereumJSONRPC.Mox)

    assert implementation_abi == @implementation_abi
  end

  test "get_implementation_abi_from_proxy/2 returns implementation abi in case of EIP-1967 proxy pattern (beacon contract) when eth_getStorageAt returns 20 bytes address" do
    proxy_contract_address = insert(:contract_address)

    smart_contract =
      insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: [], contract_code_md5: "123")

    beacon_contract_address = insert(:contract_address)

    insert(:smart_contract,
      address_hash: beacon_contract_address.hash,
      abi: @beacon_abi,
      contract_code_md5: "123"
    )

    beacon_contract_address_hash_string = Base.encode16(beacon_contract_address.hash.bytes, case: :lower)

    implementation_contract_address = insert(:contract_address)

    insert(:smart_contract,
      address_hash: implementation_contract_address.hash,
      abi: @implementation_abi,
      contract_code_md5: "123"
    )

    implementation_contract_address_hash_string =
      Base.encode16(implementation_contract_address.hash.bytes, case: :lower)

    eip_1967_beacon_proxy_mock_requests(
      beacon_contract_address_hash_string,
      implementation_contract_address_hash_string,
      :exact_20
    )

    implementation_abi = Proxy.get_implementation_abi_from_proxy(smart_contract, [])
    verify!(EthereumJSONRPC.Mox)

    assert implementation_abi == @implementation_abi
  end

  test "get_implementation_abi_from_proxy/2 returns implementation abi in case of EIP-1967 proxy pattern (beacon contract) when eth_getStorageAt returns less 20 bytes address" do
    proxy_contract_address = insert(:contract_address)

    smart_contract =
      insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: [], contract_code_md5: "123")

    beacon_contract_address = insert(:contract_address)

    insert(:smart_contract,
      address_hash: beacon_contract_address.hash,
      abi: @beacon_abi,
      contract_code_md5: "123"
    )

    beacon_contract_address_hash_string = Base.encode16(beacon_contract_address.hash.bytes, case: :lower)

    implementation_contract_address = insert(:contract_address)

    insert(:smart_contract,
      address_hash: implementation_contract_address.hash,
      abi: @implementation_abi,
      contract_code_md5: "123"
    )

    implementation_contract_address_hash_string =
      Base.encode16(implementation_contract_address.hash.bytes, case: :lower)

    eip_1967_beacon_proxy_mock_requests(
      beacon_contract_address_hash_string,
      implementation_contract_address_hash_string,
      :short
    )

    implementation_abi = Proxy.get_implementation_abi_from_proxy(smart_contract, [])
    verify!(EthereumJSONRPC.Mox)

    assert implementation_abi == @implementation_abi
  end

  test "check proxy_contract?/1 function" do
    smart_contract = insert(:smart_contract)

    proxy =
      :explorer
      |> Application.get_env(:proxy)
      |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))
      |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

    Application.put_env(:explorer, :proxy, proxy)

    refute_implementations(smart_contract.address_hash)

    # fetch nil implementation and don't save it to db
    TestHelper.get_all_proxies_implementation_zero_addresses()
    refute Proxy.proxy_contract?(smart_contract)
    verify!(EthereumJSONRPC.Mox)
    assert_empty_implementation(smart_contract.address_hash)

    proxy =
      :explorer
      |> Application.get_env(:proxy)
      |> Keyword.replace(:fallback_cached_implementation_data_ttl, 0)

    Application.put_env(:explorer, :proxy, proxy)

    TestHelper.get_eip1967_implementation_error_response()
    refute Proxy.proxy_contract?(smart_contract)
    verify!(EthereumJSONRPC.Mox)

    implementation_address = insert(:address)
    implementation_address_hash_string = to_string(implementation_address.hash)
    TestHelper.get_eip1967_implementation_non_zero_address(implementation_address_hash_string)
    assert Proxy.proxy_contract?(smart_contract)
    verify!(EthereumJSONRPC.Mox)
    assert_implementation_address(smart_contract.address_hash)

    assert Proxy.proxy_contract?(smart_contract)
    verify!(EthereumJSONRPC.Mox)
    assert_implementation_address(smart_contract.address_hash)

    proxy =
      :explorer
      |> Application.get_env(:proxy)
      |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))

    Application.put_env(:explorer, :proxy, proxy)

    assert Proxy.proxy_contract?(smart_contract)

    proxy =
      :explorer
      |> Application.get_env(:proxy)
      |> Keyword.replace(:fallback_cached_implementation_data_ttl, 0)

    Application.put_env(:explorer, :proxy, proxy)

    assert Proxy.proxy_contract?(smart_contract)
    verify!(EthereumJSONRPC.Mox)

    assert Proxy.proxy_contract?(smart_contract)
    verify!(EthereumJSONRPC.Mox)

    proxy =
      :explorer
      |> Application.get_env(:proxy)
      |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))

    Application.put_env(:explorer, :proxy, proxy)
  end

  defp eip_1967_beacon_proxy_mock_requests(
         beacon_contract_address_hash_string,
         implementation_contract_address_hash_string,
         mode
       ) do
    response =
      case mode do
        :full_32 -> "0x000000000000000000000000" <> beacon_contract_address_hash_string
        :exact_20 -> "0x" <> beacon_contract_address_hash_string
        :short -> "0x" <> String.slice(beacon_contract_address_hash_string, 10..-1//1)
      end

    EthereumJSONRPC.Mox
    |> TestHelper.mock_logic_storage_pointer_request(false)
    |> TestHelper.mock_beacon_storage_pointer_request(false, response)
    |> expect(
      :json_rpc,
      fn [
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0x5c60da1b", to: "0x" <> ^beacon_contract_address_hash_string},
               "latest"
             ]
           }
         ],
         _options ->
        {
          :ok,
          [
            %{
              id: id,
              jsonrpc: "2.0",
              result: "0x000000000000000000000000" <> implementation_contract_address_hash_string
            }
          ]
        }
      end
    )
  end

  def assert_implementation_address(address_hash) do
    implementation = Implementation.get_proxy_implementations(address_hash)
    assert implementation.proxy_type
    assert implementation.updated_at
    assert implementation.address_hashes
  end

  def refute_implementations(address_hash) do
    implementations = Implementation.get_proxy_implementations(address_hash)
    refute implementations
  end

  def assert_empty_implementation(address_hash) do
    implementation = Implementation.get_proxy_implementations(address_hash)
    assert implementation.proxy_type == :unknown
    assert implementation.updated_at
    assert implementation.names == []
    assert implementation.address_hashes == []
  end
end
