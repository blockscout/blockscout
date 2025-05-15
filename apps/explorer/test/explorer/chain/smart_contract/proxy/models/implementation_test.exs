defmodule Explorer.Chain.SmartContract.Proxy.Models.Implementation.Test do
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.TestHelper

  setup :verify_on_exit!
  setup :set_mox_global

  describe "fetching implementation" do
    test "get_implementation/1" do
      smart_contract = insert(:smart_contract)
      implementation_smart_contract = insert(:smart_contract, name: "implementation")

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))
        |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      refute_implementations(smart_contract.address_hash)

      # fetch nil implementation and don't save it to db
      TestHelper.get_all_proxies_implementation_zero_addresses()
      assert is_nil(Implementation.get_implementation(smart_contract))
      verify!(EthereumJSONRPC.Mox)
      assert_empty_implementation(smart_contract.address_hash)

      # extract proxy info from db
      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, 0)

      Application.put_env(:explorer, :proxy, proxy)

      implementation_address_hash_string = to_string(implementation_smart_contract.address_hash)

      expect_address_in_oz_slot_response(implementation_address_hash_string)
      implementation_address_hash = implementation_smart_contract.address_hash

      assert %Implementation{
               address_hashes: [^implementation_address_hash],
               names: ["implementation"],
               proxy_type: :eip1967
             } = Implementation.get_implementation(smart_contract)

      verify!(EthereumJSONRPC.Mox)

      assert_exact_name_and_address(
        smart_contract.address_hash,
        implementation_smart_contract.address_hash,
        implementation_smart_contract.name
      )

      TestHelper.get_eip1967_implementation_error_response()

      assert %Implementation{
               address_hashes: [^implementation_address_hash],
               names: ["implementation"],
               proxy_type: :eip1967
             } = Implementation.get_implementation(smart_contract)

      verify!(EthereumJSONRPC.Mox)

      assert_exact_name_and_address(
        smart_contract.address_hash,
        implementation_smart_contract.address_hash,
        implementation_smart_contract.name
      )

      {contract_1, _} = SmartContract.address_hash_to_smart_contract_with_bytecode_twin(smart_contract.address_hash)
      implementation_1 = Implementation.get_proxy_implementations(smart_contract.address_hash)

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      assert %Implementation{
               address_hashes: [^implementation_address_hash],
               names: ["implementation"],
               proxy_type: :eip1967
             } = Implementation.get_implementation(smart_contract)

      {contract_2, _} = SmartContract.address_hash_to_smart_contract_with_bytecode_twin(smart_contract.address_hash)
      implementation_2 = Implementation.get_proxy_implementations(smart_contract.address_hash)

      assert implementation_1.updated_at == implementation_2.updated_at &&
               contract_1.updated_at == contract_2.updated_at

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, 0)

      Application.put_env(:explorer, :proxy, proxy)

      TestHelper.get_all_proxies_implementation_zero_addresses()

      assert is_nil(Implementation.get_implementation(smart_contract))

      verify!(EthereumJSONRPC.Mox)

      assert implementation_1.updated_at == implementation_2.updated_at &&
               contract_1.updated_at == contract_2.updated_at

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)
    end

    test "get_implementation/1 for twins contract" do
      # return nils for nil
      assert is_nil(Implementation.get_implementation(nil))
      smart_contract = insert(:smart_contract)
      twin_address = insert(:contract_address)

      TestHelper.get_all_proxies_implementation_zero_addresses()
      {bytecode_twin, _} = SmartContract.address_hash_to_smart_contract_with_bytecode_twin(twin_address.hash)
      implementation_smart_contract = insert(:smart_contract, name: "implementation")

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))
        |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      # fetch nil implementation
      assert %Implementation{address_hashes: [], names: [], proxy_type: :unknown} =
               Implementation.get_implementation(bytecode_twin)

      verify!(EthereumJSONRPC.Mox)
      refute_implementations(smart_contract.address_hash)

      assert %Implementation{address_hashes: [], names: [], proxy_type: :unknown} =
               Implementation.get_implementation(bytecode_twin)

      verify!(EthereumJSONRPC.Mox)
      refute_implementations(smart_contract.address_hash)

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(0))
        |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      string_implementation_address_hash = to_string(implementation_smart_contract.address_hash)

      expect_address_in_oz_slot_response(string_implementation_address_hash)
      implementation_address_hash = implementation_smart_contract.address_hash

      assert %Implementation{
               address_hashes: [^implementation_address_hash],
               names: ["implementation"],
               proxy_type: :eip1967
             } =
               Implementation.get_implementation(bytecode_twin)

      verify!(EthereumJSONRPC.Mox)

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))
        |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      refute_implementations(smart_contract.address_hash)

      assert %Implementation{
               address_hashes: [^implementation_address_hash],
               names: ["implementation"],
               proxy_type: :eip1967
             } =
               Implementation.get_implementation(bytecode_twin)

      verify!(EthereumJSONRPC.Mox)

      refute_implementations(smart_contract.address_hash)

      {:ok, addr} = Chain.hash_to_address(twin_address.hash)
      bytecode_twin = addr.smart_contract

      _implementation_smart_contract = insert(:smart_contract, name: "implementation")

      # fetch nil implementation
      assert is_nil(Implementation.get_implementation(bytecode_twin))
      verify!(EthereumJSONRPC.Mox)
      refute_implementations(smart_contract.address_hash)

      assert is_nil(Implementation.get_implementation(bytecode_twin))
      verify!(EthereumJSONRPC.Mox)
      refute_implementations(smart_contract.address_hash)

      # todo: return this part of test
      # proxy =
      #   :explorer
      #   |> Application.get_env(:proxy)
      #   |> Keyword.replace(:fallback_cached_implementation_data_ttl, 0)
      #   |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      # Application.put_env(:explorer, :proxy, proxy)

      # string_implementation_address_hash = to_string(implementation_smart_contract.address_hash)

      # expect_address_in_oz_slot_response(string_implementation_address_hash)

      # assert {^string_implementation_address_hash, "implementation", :eip1967} = Implementation.get_implementation(bytecode_twin)

      # verify!(EthereumJSONRPC.Mox)

      # refute_implementations(smart_contract.address_hash)

      # TestHelper.get_eip1967_implementation_error_response()

      # assert {^string_implementation_address_hash, "implementation", :eip1967} = Implementation.get_implementation(bytecode_twin)

      # verify!(EthereumJSONRPC.Mox)

      # refute_implementations(smart_contract.address_hash)

      # TestHelper.get_all_proxies_implementation_zero_addresses()

      # {:ok, addr} =
      #   Chain.find_contract_address(
      #     twin_address.hash,
      #     [
      #       necessity_by_association: %{
      #         :smart_contract => :optional
      #       }
      #     ]
      #   )

      # bytecode_twin = addr.smart_contract

      # implementation_smart_contract = insert(:smart_contract, name: "implementation")

      # proxy =
      #   :explorer
      #   |> Application.get_env(:proxy)
      #   |> Keyword.replace(:fallback_cached_implementation_data_ttl, 0)
      #   |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      # Application.put_env(:explorer, :proxy, proxy)

      # # fetch nil implementation
      # TestHelper.get_all_proxies_implementation_zero_addresses()
      # assert {[], [], nil} = Implementation.get_implementation(bytecode_twin)
      # verify!(EthereumJSONRPC.Mox)
      # refute_implementations(smart_contract.address_hash)

      # TestHelper.get_all_proxies_implementation_zero_addresses()
      # assert {[], [], nil} = Implementation.get_implementation(bytecode_twin)
      # verify!(EthereumJSONRPC.Mox)
      # refute_implementations(smart_contract.address_hash)

      # string_implementation_address_hash = to_string(implementation_smart_contract.address_hash)

      # expect_address_in_oz_slot_response(string_implementation_address_hash)

      # assert {^string_implementation_address_hash, "implementation", :eip1967} = Implementation.get_implementation(bytecode_twin)

      # verify!(EthereumJSONRPC.Mox)

      # refute_implementations(smart_contract.address_hash)

      # TestHelper.get_all_proxies_implementation_zero_addresses()

      # assert {[], [], nil} = Implementation.get_implementation(bytecode_twin)

      # verify!(EthereumJSONRPC.Mox)

      # refute_implementations(smart_contract.address_hash)
    end
  end

  def assert_exact_name_and_address(address_hash, implementation_address_hash, implementation_name) do
    implementation = Implementation.get_proxy_implementations(address_hash)
    assert implementation.proxy_type
    assert implementation.updated_at
    assert implementation.names == [implementation_name]

    assert to_string(implementation.address_hashes |> Enum.at(0)) ==
             to_string(implementation_address_hash)
  end

  def assert_implementation_name(address_hash) do
    implementation = Implementation.get_proxy_implementations(address_hash)
    assert implementation.proxy_type
    assert implementation.updated_at
    assert implementation.names
  end

  defp expect_address_in_oz_slot_response(string_implementation_address_hash) do
    EthereumJSONRPC.Mox
    |> TestHelper.mock_logic_storage_pointer_request(false)
    |> TestHelper.mock_beacon_storage_pointer_request(false)
    |> TestHelper.mock_oz_storage_pointer_request(false, string_implementation_address_hash)
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
