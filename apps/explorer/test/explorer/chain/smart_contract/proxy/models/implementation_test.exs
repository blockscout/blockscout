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

      # fetch nil implementation
      EthereumJSONRPC.Mox
      |> TestHelper.mock_generic_proxy_requests()

      assert %Implementation{address_hashes: [], names: [], proxy_type: nil} =
               Implementation.get_implementation(smart_contract)

      verify!(EthereumJSONRPC.Mox)
      assert_empty_implementation(smart_contract.address_hash)

      # extract proxy info from db
      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, 0)

      Application.put_env(:explorer, :proxy, proxy)

      implementation_address_hash = implementation_smart_contract.address_hash

      EthereumJSONRPC.Mox
      |> TestHelper.mock_generic_proxy_requests(eip1967_oz: implementation_address_hash)

      assert %Implementation{
               address_hashes: [^implementation_address_hash],
               names: ["implementation"],
               proxy_type: :eip1967_oz
             } = Implementation.get_implementation(smart_contract)

      verify!(EthereumJSONRPC.Mox)

      assert_exact_name_and_address(
        smart_contract.address_hash,
        implementation_smart_contract.address_hash,
        implementation_smart_contract.name
      )

      EthereumJSONRPC.Mox
      |> TestHelper.mock_generic_proxy_requests(eip1967: :error)

      assert %Implementation{
               address_hashes: [^implementation_address_hash],
               names: ["implementation"],
               proxy_type: :eip1967_oz
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
               proxy_type: :eip1967_oz
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

      EthereumJSONRPC.Mox
      |> TestHelper.mock_generic_proxy_requests()

      assert %Implementation{address_hashes: [], names: [], proxy_type: nil} =
               Implementation.get_implementation(smart_contract)

      verify!(EthereumJSONRPC.Mox)
      assert_empty_implementation(smart_contract.address_hash)

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

      EthereumJSONRPC.Mox
      |> TestHelper.mock_generic_proxy_requests()

      {bytecode_twin, _} = SmartContract.address_hash_to_smart_contract_with_bytecode_twin(twin_address.hash)
      implementation_smart_contract = insert(:smart_contract, name: "implementation")

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))
        |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      # fetch nil implementation
      assert %Implementation{address_hashes: [], names: [], proxy_type: nil} =
               Implementation.get_implementation(bytecode_twin)

      verify!(EthereumJSONRPC.Mox)
      assert_empty_implementation(bytecode_twin.address_hash)
      refute_implementations(smart_contract.address_hash)

      assert %Implementation{address_hashes: [], names: [], proxy_type: nil} =
               Implementation.get_implementation(bytecode_twin)

      verify!(EthereumJSONRPC.Mox)
      assert_empty_implementation(bytecode_twin.address_hash)
      refute_implementations(smart_contract.address_hash)

      proxy =
        :explorer
        |> Application.get_env(:proxy)
        |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(0))
        |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

      Application.put_env(:explorer, :proxy, proxy)

      implementation_address_hash = implementation_smart_contract.address_hash

      EthereumJSONRPC.Mox
      |> TestHelper.mock_generic_proxy_requests(eip1967: implementation_address_hash)

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

      # EthereumJSONRPC.Mox
      # |> TestHelper.mock_generic_proxy_requests()

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
      # EthereumJSONRPC.Mox
      # |> TestHelper.mock_generic_proxy_requests()
      # assert {[], [], nil} = Implementation.get_implementation(bytecode_twin)
      # verify!(EthereumJSONRPC.Mox)
      # refute_implementations(smart_contract.address_hash)

      # EthereumJSONRPC.Mox
      # |> TestHelper.mock_generic_proxy_requests()
      # assert {[], [], nil} = Implementation.get_implementation(bytecode_twin)
      # verify!(EthereumJSONRPC.Mox)
      # refute_implementations(smart_contract.address_hash)

      # string_implementation_address_hash = to_string(implementation_smart_contract.address_hash)

      # expect_address_in_oz_slot_response(string_implementation_address_hash)

      # assert {^string_implementation_address_hash, "implementation", :eip1967} = Implementation.get_implementation(bytecode_twin)

      # verify!(EthereumJSONRPC.Mox)

      # refute_implementations(smart_contract.address_hash)

      # EthereumJSONRPC.Mox
      # |> TestHelper.mock_generic_proxy_requests()

      # assert {[], [], nil} = Implementation.get_implementation(bytecode_twin)

      # verify!(EthereumJSONRPC.Mox)

      # refute_implementations(smart_contract.address_hash)
    end
  end

  test "get_implementation/1 with conflicting implementations" do
    smart_contract = insert(:smart_contract)
    implementation_smart_contract1 = insert(:smart_contract, name: "implementation1")
    implementation_smart_contract2 = insert(:smart_contract, name: "implementation2")
    implementation_smart_contract3 = insert(:smart_contract, name: "implementation3")

    implementation_address_hash1 = implementation_smart_contract1.address_hash
    implementation_address_hash2 = implementation_smart_contract2.address_hash
    implementation_address_hash3 = implementation_smart_contract3.address_hash

    EthereumJSONRPC.Mox
    |> TestHelper.mock_generic_proxy_requests(
      eip1967: implementation_address_hash1,
      eip1967_oz: implementation_address_hash1,
      eip1822: implementation_address_hash1
    )

    assert %Implementation{
             address_hashes: [^implementation_address_hash1],
             names: ["implementation1"],
             proxy_type: :eip1967,
             conflicting_proxy_types: nil,
             conflicting_address_hashes: nil
           } = Implementation.get_implementation(smart_contract)

    verify!(EthereumJSONRPC.Mox)

    assert_exact_name_and_address(
      smart_contract.address_hash,
      implementation_address_hash1,
      implementation_smart_contract1.name
    )

    assert %Implementation{
             conflicting_proxy_types: nil,
             conflicting_address_hashes: nil
           } = Implementation.get_proxy_implementations(smart_contract.address_hash)

    proxy =
      :explorer
      |> Application.get_env(:proxy)
      |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(0))
      |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

    Application.put_env(:explorer, :proxy, proxy)

    EthereumJSONRPC.Mox
    |> TestHelper.mock_generic_proxy_requests(
      eip1967: implementation_address_hash1,
      eip1967_oz: implementation_address_hash2,
      eip1822: implementation_address_hash3
    )

    assert %Implementation{
             address_hashes: [^implementation_address_hash1],
             names: ["implementation1"],
             proxy_type: :eip1967,
             conflicting_proxy_types: [:eip1822, :eip1967_oz],
             conflicting_address_hashes: [[^implementation_address_hash3], [^implementation_address_hash2]]
           } = Implementation.get_implementation(smart_contract)

    verify!(EthereumJSONRPC.Mox)

    proxy =
      :explorer
      |> Application.get_env(:proxy)
      |> Keyword.replace(:fallback_cached_implementation_data_ttl, :timer.seconds(20))
      |> Keyword.replace(:implementation_data_fetching_timeout, :timer.seconds(20))

    Application.put_env(:explorer, :proxy, proxy)

    assert_exact_name_and_address(
      smart_contract.address_hash,
      implementation_address_hash1,
      implementation_smart_contract1.name
    )

    assert %Implementation{
             conflicting_proxy_types: [:eip1822, :eip1967_oz],
             conflicting_address_hashes: [[^implementation_address_hash3], [^implementation_address_hash2]]
           } = Implementation.get_proxy_implementations(smart_contract.address_hash)
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

  def refute_implementations(address_hash) do
    implementations = Implementation.get_proxy_implementations(address_hash)
    refute implementations
  end

  def assert_empty_implementation(address_hash) do
    implementation = Implementation.get_proxy_implementations(address_hash)
    assert is_nil(implementation.proxy_type)
    assert implementation.updated_at
    assert implementation.names == []
    assert implementation.address_hashes == []
    assert is_nil(implementation.conflicting_proxy_types)
    assert is_nil(implementation.conflicting_address_hashes)
  end
end
