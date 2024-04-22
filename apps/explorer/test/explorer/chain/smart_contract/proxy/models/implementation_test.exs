defmodule Explorer.Chain.SmartContract.Proxy.Models.Implementation.Test do
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation

  setup :verify_on_exit!
  setup :set_mox_global

  describe "test fetching implementation" do
    test "check proxy_contract/1 function" do
      smart_contract = insert(:smart_contract)

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))
        |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      assert_implementation_never_fetched(smart_contract.address_hash)

      # fetch nil implementation and don't save it to db
      get_eip1967_implementation_zero_addresses()
      refute Proxy.proxy_contract?(smart_contract)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, 0)

      Application.put_env(:explorer, :proxy, proxy)

      get_eip1967_implementation_error_response()
      refute Proxy.proxy_contract?(smart_contract)
      verify!(EthereumJSONRPC.Mox)

      get_eip1967_implementation_non_zero_address()
      assert Proxy.proxy_contract?(smart_contract)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_address(smart_contract.address_hash)

      get_eip1967_implementation_non_zero_address()
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

      get_eip1967_implementation_non_zero_address()
      assert Proxy.proxy_contract?(smart_contract)
      verify!(EthereumJSONRPC.Mox)

      get_eip1967_implementation_error_response()
      assert Proxy.proxy_contract?(smart_contract)
      verify!(EthereumJSONRPC.Mox)
    end

    test "get_implementation_address_hash/1" do
      smart_contract = insert(:smart_contract)
      implementation_smart_contract = insert(:smart_contract, name: "proxy")

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))
        |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      assert_implementation_never_fetched(smart_contract.address_hash)

      # fetch nil implementation and don't save it to db
      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = Implementation.get_implementation_address_hash(smart_contract)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      # extract proxy info from db
      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, 0)

      Application.put_env(:explorer, :proxy, proxy)

      string_implementation_address_hash = to_string(implementation_smart_contract.address_hash)

      mock_empty_logic_storage_pointer_request()
      |> mock_empty_beacon_storage_pointer_request()
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
        {:ok, string_implementation_address_hash}
      end)

      assert {^string_implementation_address_hash, "proxy"} =
               Implementation.get_implementation_address_hash(smart_contract)

      verify!(EthereumJSONRPC.Mox)

      assert_exact_name_and_address(
        smart_contract.address_hash,
        implementation_smart_contract.address_hash,
        implementation_smart_contract.name
      )

      get_eip1967_implementation_error_response()

      assert {^string_implementation_address_hash, "proxy"} =
               Implementation.get_implementation_address_hash(smart_contract)

      verify!(EthereumJSONRPC.Mox)

      assert_exact_name_and_address(
        smart_contract.address_hash,
        implementation_smart_contract.address_hash,
        implementation_smart_contract.name
      )

      contract_1 = SmartContract.address_hash_to_smart_contract_with_twin(smart_contract.address_hash)
      implementation_1 = Implementation.get_proxy_implementation(smart_contract.address_hash)

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      assert {^string_implementation_address_hash, "proxy"} =
               Implementation.get_implementation_address_hash(smart_contract)

      contract_2 = SmartContract.address_hash_to_smart_contract_with_twin(smart_contract.address_hash)
      implementation_2 = Implementation.get_proxy_implementation(smart_contract.address_hash)

      assert implementation_1.updated_at == implementation_2.updated_at &&
               contract_1.updated_at == contract_2.updated_at

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, 0)

      Application.put_env(:explorer, :proxy, proxy)
      get_eip1967_implementation_zero_addresses()

      assert {^string_implementation_address_hash, "proxy"} =
               Implementation.get_implementation_address_hash(smart_contract)

      verify!(EthereumJSONRPC.Mox)

      assert implementation_1.updated_at == implementation_2.updated_at &&
               contract_1.updated_at == contract_2.updated_at
    end

    test "get_implementation_address_hash/1 for twins contract" do
      # return nils for nil
      assert {nil, nil} = Implementation.get_implementation_address_hash(nil)
      smart_contract = insert(:smart_contract)
      twin_address = insert(:contract_address)

      twin = SmartContract.address_hash_to_smart_contract_with_twin(twin_address.hash)
      implementation_smart_contract = insert(:smart_contract, name: "proxy")

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))
        |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      # fetch nil implementation
      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = Implementation.get_implementation_address_hash(twin)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = Implementation.get_implementation_address_hash(twin)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      string_implementation_address_hash = to_string(implementation_smart_contract.address_hash)

      expect_address_in_response(string_implementation_address_hash)

      assert {^string_implementation_address_hash, "proxy"} = Implementation.get_implementation_address_hash(twin)

      verify!(EthereumJSONRPC.Mox)

      assert_implementation_never_fetched(smart_contract.address_hash)

      get_eip1967_implementation_error_response()

      assert {nil, nil} = Implementation.get_implementation_address_hash(twin)

      verify!(EthereumJSONRPC.Mox)

      assert_implementation_never_fetched(smart_contract.address_hash)

      {:ok, addr} = Chain.hash_to_address(twin_address.hash)
      twin = addr.smart_contract

      implementation_smart_contract = insert(:smart_contract, name: "proxy")

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))
        |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      # fetch nil implementation
      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = Implementation.get_implementation_address_hash(twin)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = Implementation.get_implementation_address_hash(twin)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      string_implementation_address_hash = to_string(implementation_smart_contract.address_hash)

      expect_address_in_response(string_implementation_address_hash)

      assert {^string_implementation_address_hash, "proxy"} = Implementation.get_implementation_address_hash(twin)

      verify!(EthereumJSONRPC.Mox)

      assert_implementation_never_fetched(smart_contract.address_hash)

      get_eip1967_implementation_error_response()

      assert {nil, nil} = Implementation.get_implementation_address_hash(twin)

      verify!(EthereumJSONRPC.Mox)

      assert_implementation_never_fetched(smart_contract.address_hash)

      {:ok, addr} =
        Chain.find_contract_address(
          twin_address.hash,
          [
            necessity_by_association: %{
              :smart_contract => :optional
            }
          ],
          true
        )

      twin = addr.smart_contract

      implementation_smart_contract = insert(:smart_contract, name: "proxy")

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))
        |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      # fetch nil implementation
      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = Implementation.get_implementation_address_hash(twin)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = Implementation.get_implementation_address_hash(twin)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      string_implementation_address_hash = to_string(implementation_smart_contract.address_hash)

      expect_address_in_response(string_implementation_address_hash)

      assert {^string_implementation_address_hash, "proxy"} = Implementation.get_implementation_address_hash(twin)

      verify!(EthereumJSONRPC.Mox)

      assert_implementation_never_fetched(smart_contract.address_hash)

      get_eip1967_implementation_error_response()

      assert {nil, nil} = Implementation.get_implementation_address_hash(twin)

      verify!(EthereumJSONRPC.Mox)

      assert_implementation_never_fetched(smart_contract.address_hash)
    end
  end

  def get_eip1967_implementation_zero_addresses do
    mock_empty_logic_storage_pointer_request()
    |> mock_empty_beacon_storage_pointer_request()
    |> mock_empty_oz_storage_pointer_request()
    |> mock_empty_eip_1822_storage_pointer_request()
  end

  def get_eip1967_implementation_non_zero_address do
    mock_empty_logic_storage_pointer_request()
    |> mock_empty_beacon_storage_pointer_request()
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
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000001"}
    end)
  end

  def get_eip1967_implementation_error_response do
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
      {:error, "error"}
    end)
    |> mock_empty_beacon_storage_pointer_request()
    |> mock_empty_oz_storage_pointer_request()
    |> mock_empty_eip_1822_storage_pointer_request()
  end

  def assert_exact_name_and_address(address_hash, implementation_address_hash, implementation_name) do
    implementation = Implementation.get_proxy_implementation(address_hash)
    assert implementation.updated_at
    assert implementation.name == implementation_name
    assert to_string(implementation.address_hash) == to_string(implementation_address_hash)
  end

  def assert_empty_implementation(address_hash) do
    implementation = Implementation.get_proxy_implementation(address_hash)
    assert implementation.updated_at
    refute implementation.name
    refute implementation.address_hash
  end

  def assert_implementation_never_fetched(address_hash) do
    implementation = Implementation.get_proxy_implementation(address_hash)
    refute implementation
  end

  def assert_implementation_address(address_hash) do
    implementation = Implementation.get_proxy_implementation(address_hash)
    assert implementation.updated_at
    assert implementation.address_hash
  end

  def assert_implementation_name(address_hash) do
    implementation = Implementation.get_proxy_implementation(address_hash)
    assert implementation.updated_at
    assert implementation.name
  end

  defp expect_address_in_response(string_implementation_address_hash) do
    mock_empty_logic_storage_pointer_request()
    |> mock_empty_beacon_storage_pointer_request()
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
      {:ok, string_implementation_address_hash}
    end)
  end

  defp mock_empty_logic_storage_pointer_request do
    expect(EthereumJSONRPC.Mox, :json_rpc, fn %{
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
  end

  defp mock_empty_beacon_storage_pointer_request(mox) do
    expect(mox, :json_rpc, fn %{
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
  end

  defp mock_empty_eip_1822_storage_pointer_request(mox) do
    expect(mox, :json_rpc, fn %{
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

  defp mock_empty_oz_storage_pointer_request(mox) do
    expect(mox, :json_rpc, fn %{
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
  end
end
