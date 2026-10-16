# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemandTest do
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand

  @ets_table :smart_contracts_sources_fetching

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    initial_config =
      Application.get_env(:explorer, LookUpSmartContractSourcesOnDemand) || []

    Application.put_env(
      :explorer,
      LookUpSmartContractSourcesOnDemand,
      Keyword.merge(initial_config, fetch_interval: 0)
    )

    on_exit(fn ->
      Application.put_env(:explorer, LookUpSmartContractSourcesOnDemand, initial_config)
    end)

    start_supervised!(LookUpSmartContractSourcesOnDemand)

    :ok
  end

  describe "bytecode proxy exclusion" do
    @bytecode_proxy_types [:eip1167, :eip7702, :minimal_proxy, :clone_with_immutable_arguments, :erc7760]

    for proxy_type <- @bytecode_proxy_types do
      test "skips verification for #{proxy_type} proxy" do
        address = insert(:contract_address)
        implementation_address = insert(:contract_address)
        implementation_sc = insert(:smart_contract, address_hash: implementation_address.hash, contract_code_md5: "abc")

        insert(:proxy_implementation,
          proxy_address_hash: address.hash,
          proxy_type: unquote(to_string(proxy_type)),
          address_hashes: [implementation_address.hash],
          names: [implementation_sc.name]
        )

        address_hash_string = to_string(address.hash)
        GenServer.cast(LookUpSmartContractSourcesOnDemand, {:check_eligibility, address_hash_string})

        :timer.sleep(50)

        assert :ets.lookup(@ets_table, String.downcase(address_hash_string)) == []
      end
    end

    test "does not skip verification for non-bytecode proxy types" do
      Explorer.Mock.TeslaAdapter
      |> stub(:call, fn env, _opts ->
        {:ok, %Tesla.Env{env | status: 200, body: Jason.encode!(%{"sources" => []})}}
      end)

      address = insert(:contract_address)
      implementation_address = insert(:contract_address)
      implementation_sc = insert(:smart_contract, address_hash: implementation_address.hash, contract_code_md5: "abc")

      insert(:proxy_implementation,
        proxy_address_hash: address.hash,
        proxy_type: "eip1967",
        address_hashes: [implementation_address.hash],
        names: [implementation_sc.name]
      )

      address_hash_string = to_string(address.hash)
      GenServer.cast(LookUpSmartContractSourcesOnDemand, {:check_eligibility, address_hash_string})

      :timer.sleep(100)

      assert :ets.lookup(@ets_table, String.downcase(address_hash_string)) != []
    end

    test "does not skip verification for address without proxy implementation" do
      Explorer.Mock.TeslaAdapter
      |> stub(:call, fn env, _opts ->
        {:ok, %Tesla.Env{env | status: 200, body: Jason.encode!(%{"sources" => []})}}
      end)

      address = insert(:contract_address)

      address_hash_string = to_string(address.hash)
      GenServer.cast(LookUpSmartContractSourcesOnDemand, {:check_eligibility, address_hash_string})

      :timer.sleep(100)

      assert :ets.lookup(@ets_table, String.downcase(address_hash_string)) != []
    end
  end

  describe "creation data" do
    test "keeps chainId in the metadata and does not discover creation data on demand" do
      test_pid = self()

      # No `EthereumJSONRPC.Mox` expectations are set: a nonce or trace request
      # would raise in the fetcher and the request below would never be sent.
      Explorer.Mock.TeslaAdapter
      |> stub(:call, fn %Tesla.Env{} = env, _opts ->
        send(test_pid, {:eth_bytecode_db_request, Jason.decode!(env.body)})
        {:ok, %Tesla.Env{env | status: 200, body: Jason.encode!(%{"sources" => []})}}
      end)

      address = insert(:contract_address)

      GenServer.cast(LookUpSmartContractSourcesOnDemand, {:check_eligibility, to_string(address.hash)})

      assert_receive {:eth_bytecode_db_request, body}, 1_000

      assert body["bytecodeType"] == "DEPLOYED_BYTECODE"
      assert Map.has_key?(body["metadata"], "chainId")
      assert body["metadata"]["contractAddress"] == to_string(address.hash)
      refute Map.has_key?(body["metadata"], "creationCode")
    end
  end
end
