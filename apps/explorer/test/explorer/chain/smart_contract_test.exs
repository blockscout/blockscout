defmodule Explorer.Chain.SmartContractTest do
  use Explorer.DataCase, async: false

  import Mox
  alias Explorer.Chain
  alias Explorer.Chain.SmartContract

  doctest Explorer.Chain.SmartContract

  setup :verify_on_exit!
  setup :set_mox_global

  describe "test fetching implementation" do
    test "check proxy_contract/1 function" do
      smart_contract = insert(:smart_contract)

      Application.put_env(:explorer, :fallback_ttl_cached_implementation_data_of_proxy, :timer.seconds(20))
      Application.put_env(:explorer, :implementation_data_fetching_timeout, :timer.seconds(20))

      refute smart_contract.implementation_fetched_at

      # fetch nil implementation and save it to db
      get_eip1967_implementation_zero_addresses()
      refute SmartContract.proxy_contract?(smart_contract)
      verify!(EthereumJSONRPC.Mox)
      assert_empty_implementation(smart_contract.address_hash)
      # extract proxy info from db
      refute SmartContract.proxy_contract?(smart_contract)
      verify!(EthereumJSONRPC.Mox)
      assert_empty_implementation(smart_contract.address_hash)

      Application.put_env(:explorer, :fallback_ttl_cached_implementation_data_of_proxy, 0)

      get_eip1967_implementation_error_response()
      refute SmartContract.proxy_contract?(smart_contract)
      verify!(EthereumJSONRPC.Mox)

      get_eip1967_implementation_non_zero_address()
      assert SmartContract.proxy_contract?(smart_contract)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_address(smart_contract.address_hash)

      get_eip1967_implementation_non_zero_address()
      assert SmartContract.proxy_contract?(smart_contract)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_address(smart_contract.address_hash)

      Application.put_env(:explorer, :fallback_ttl_cached_implementation_data_of_proxy, :timer.seconds(20))
      assert SmartContract.proxy_contract?(smart_contract)

      Application.put_env(:explorer, :fallback_ttl_cached_implementation_data_of_proxy, 0)
      get_eip1967_implementation_non_zero_address()
      assert SmartContract.proxy_contract?(smart_contract)
      verify!(EthereumJSONRPC.Mox)

      get_eip1967_implementation_error_response()
      assert SmartContract.proxy_contract?(smart_contract)
      verify!(EthereumJSONRPC.Mox)
    end

    test "test get_implementation_adddress_hash/1" do
      smart_contract = insert(:smart_contract)
      implementation_smart_contract = insert(:smart_contract, name: "proxy")

      Application.put_env(:explorer, :fallback_ttl_cached_implementation_data_of_proxy, :timer.seconds(20))
      Application.put_env(:explorer, :implementation_data_fetching_timeout, :timer.seconds(20))

      refute smart_contract.implementation_fetched_at

      # fetch nil implementation and save it to db
      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = SmartContract.get_implementation_address_hash(smart_contract)
      verify!(EthereumJSONRPC.Mox)
      assert_empty_implementation(smart_contract.address_hash)

      # extract proxy info from db
      assert {nil, nil} = SmartContract.get_implementation_address_hash(smart_contract)
      assert_empty_implementation(smart_contract.address_hash)

      Application.put_env(:explorer, :fallback_ttl_cached_implementation_data_of_proxy, 0)

      string_implementation_address_hash = to_string(implementation_smart_contract.address_hash)

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
        {:ok, string_implementation_address_hash}
      end)

      assert {^string_implementation_address_hash, "proxy"} =
               SmartContract.get_implementation_address_hash(smart_contract)

      verify!(EthereumJSONRPC.Mox)

      assert_exact_name_and_address(
        smart_contract.address_hash,
        implementation_smart_contract.address_hash,
        implementation_smart_contract.name
      )

      get_eip1967_implementation_error_response()

      assert {^string_implementation_address_hash, "proxy"} =
               SmartContract.get_implementation_address_hash(smart_contract)

      verify!(EthereumJSONRPC.Mox)

      assert_exact_name_and_address(
        smart_contract.address_hash,
        implementation_smart_contract.address_hash,
        implementation_smart_contract.name
      )

      contract_1 = Chain.address_hash_to_smart_contract(smart_contract.address_hash)

      Application.put_env(:explorer, :fallback_ttl_cached_implementation_data_of_proxy, :timer.seconds(20))

      assert {^string_implementation_address_hash, "proxy"} =
               SmartContract.get_implementation_address_hash(smart_contract)

      contract_2 = Chain.address_hash_to_smart_contract(smart_contract.address_hash)

      assert contract_1.implementation_fetched_at == contract_2.implementation_fetched_at &&
               contract_1.updated_at == contract_2.updated_at

      Application.put_env(:explorer, :fallback_ttl_cached_implementation_data_of_proxy, 0)
      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = SmartContract.get_implementation_address_hash(smart_contract)
      verify!(EthereumJSONRPC.Mox)
      assert_empty_implementation(smart_contract.address_hash)
    end

    test "test get_implementation_adddress_hash/1 for twins contract" do
      # return nils for nil
      assert {nil, nil} = SmartContract.get_implementation_address_hash(nil)
      smart_contract = insert(:smart_contract)
      another_address = insert(:contract_address)

      twin = Chain.address_hash_to_smart_contract(another_address.hash)
      implementation_smart_contract = insert(:smart_contract, name: "proxy")

      Application.put_env(:explorer, :fallback_ttl_cached_implementation_data_of_proxy, :timer.seconds(20))
      Application.put_env(:explorer, :implementation_data_fetching_timeout, :timer.seconds(20))

      # fetch nil implementation
      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = SmartContract.get_implementation_address_hash(twin)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = SmartContract.get_implementation_address_hash(twin)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      string_implementation_address_hash = to_string(implementation_smart_contract.address_hash)

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
        {:ok, string_implementation_address_hash}
      end)

      assert {^string_implementation_address_hash, "proxy"} = SmartContract.get_implementation_address_hash(twin)

      verify!(EthereumJSONRPC.Mox)

      assert_implementation_never_fetched(smart_contract.address_hash)

      get_eip1967_implementation_error_response()

      assert {nil, nil} = SmartContract.get_implementation_address_hash(twin)

      verify!(EthereumJSONRPC.Mox)

      assert_implementation_never_fetched(smart_contract.address_hash)

      {:ok, addr} = Chain.hash_to_address(another_address.hash)
      twin = addr.smart_contract

      implementation_smart_contract = insert(:smart_contract, name: "proxy")

      Application.put_env(:explorer, :fallback_ttl_cached_implementation_data_of_proxy, :timer.seconds(20))
      Application.put_env(:explorer, :implementation_data_fetching_timeout, :timer.seconds(20))

      # fetch nil implementation
      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = SmartContract.get_implementation_address_hash(twin)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = SmartContract.get_implementation_address_hash(twin)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      string_implementation_address_hash = to_string(implementation_smart_contract.address_hash)

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
        {:ok, string_implementation_address_hash}
      end)

      assert {^string_implementation_address_hash, "proxy"} = SmartContract.get_implementation_address_hash(twin)

      verify!(EthereumJSONRPC.Mox)

      assert_implementation_never_fetched(smart_contract.address_hash)

      get_eip1967_implementation_error_response()

      assert {nil, nil} = SmartContract.get_implementation_address_hash(twin)

      verify!(EthereumJSONRPC.Mox)

      assert_implementation_never_fetched(smart_contract.address_hash)

      {:ok, addr} =
        Chain.find_contract_address(
          another_address.hash,
          [
            necessity_by_association: %{
              :smart_contract => :optional
            }
          ],
          true
        )

      twin = addr.smart_contract

      implementation_smart_contract = insert(:smart_contract, name: "proxy")

      Application.put_env(:explorer, :fallback_ttl_cached_implementation_data_of_proxy, :timer.seconds(20))
      Application.put_env(:explorer, :implementation_data_fetching_timeout, :timer.seconds(20))

      # fetch nil implementation
      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = SmartContract.get_implementation_address_hash(twin)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      get_eip1967_implementation_zero_addresses()
      assert {nil, nil} = SmartContract.get_implementation_address_hash(twin)
      verify!(EthereumJSONRPC.Mox)
      assert_implementation_never_fetched(smart_contract.address_hash)

      string_implementation_address_hash = to_string(implementation_smart_contract.address_hash)

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
        {:ok, string_implementation_address_hash}
      end)

      assert {^string_implementation_address_hash, "proxy"} = SmartContract.get_implementation_address_hash(twin)

      verify!(EthereumJSONRPC.Mox)

      assert_implementation_never_fetched(smart_contract.address_hash)

      get_eip1967_implementation_error_response()

      assert {nil, nil} = SmartContract.get_implementation_address_hash(twin)

      verify!(EthereumJSONRPC.Mox)

      assert_implementation_never_fetched(smart_contract.address_hash)
    end
  end

  def get_eip1967_implementation_zero_addresses do
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
  end

  def get_eip1967_implementation_non_zero_address do
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
  end

  def assert_empty_implementation(address_hash) do
    contract = Chain.address_hash_to_smart_contract(address_hash)
    assert contract.implementation_fetched_at
    refute contract.implementation_name
    refute contract.implementation_address_hash
  end

  def assert_implementation_never_fetched(address_hash) do
    contract = Chain.address_hash_to_smart_contract(address_hash)
    refute contract.implementation_fetched_at
    refute contract.implementation_name
    refute contract.implementation_address_hash
  end

  def assert_implementation_address(address_hash) do
    contract = Chain.address_hash_to_smart_contract(address_hash)
    assert contract.implementation_fetched_at
    assert contract.implementation_address_hash
  end

  def assert_implementation_name(address_hash) do
    contract = Chain.address_hash_to_smart_contract(address_hash)
    assert contract.implementation_fetched_at
    assert contract.implementation_name
  end

  def assert_exact_name_and_address(address_hash, implementation_address_hash, implementation_name) do
    contract = Chain.address_hash_to_smart_contract(address_hash)
    assert contract.implementation_fetched_at
    assert contract.implementation_name == implementation_name
    assert to_string(contract.implementation_address_hash) == to_string(implementation_address_hash)
  end
end
