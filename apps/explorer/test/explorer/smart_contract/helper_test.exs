# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.SmartContract.HelperTest do
  use ExUnit.Case, async: false
  use Explorer.DataCase

  import Mox
  setup :verify_on_exit!

  alias Explorer.Chain.Data
  alias Explorer.SmartContract.{CreationDataResolver, Helper}

  @internal_transaction_fetcher_supervisor Indexer.Fetcher.InternalTransaction.Supervisor
  @creation_fields ~w(blockNumber transactionHash transactionIndex deployer creationCode)

  describe "payable?" do
    test "returns true when there is payable function" do
      function = %{
        "type" => "function",
        "stateMutability" => "payable",
        "payable" => true,
        "outputs" => [],
        "name" => "upgradeToAndCall",
        "inputs" => [
          %{"type" => "uint256", "name" => "version"},
          %{"type" => "address", "name" => "implementation"},
          %{"type" => "bytes", "name" => "data"}
        ],
        "constant" => false
      }

      assert Helper.payable?(function)
    end

    test "returns true when there is old-style payable function" do
      function = %{
        "type" => "function",
        "payable" => true,
        "outputs" => [],
        "name" => "upgradeToAndCall",
        "inputs" => [
          %{"type" => "uint256", "name" => "version"},
          %{"type" => "address", "name" => "implementation"},
          %{"type" => "bytes", "name" => "data"}
        ],
        "constant" => false
      }

      assert Helper.payable?(function)
    end

    test "returns false when it is nonpayable function" do
      function = %{
        "type" => "function",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "outputs" => [],
        "name" => "transferProxyOwnership",
        "inputs" => [%{"type" => "address", "name" => "newOwner"}],
        "constant" => false
      }

      refute Helper.payable?(function)
    end

    test "returns false when there is no function" do
      function = %{}

      refute Helper.payable?(function)
    end

    test "returns false when function is nil" do
      function = nil

      refute Helper.payable?(function)
    end
  end

  describe "nonpayable?" do
    test "returns true when there is nonpayable function" do
      function = %{
        "type" => "function",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "outputs" => [],
        "name" => "transferProxyOwnership",
        "inputs" => [%{"type" => "address", "name" => "newOwner"}],
        "constant" => false
      }

      assert Helper.nonpayable?(function)
    end

    test "returns true when there is old-style nonpayable function" do
      function = %{
        "type" => "function",
        "outputs" => [],
        "name" => "test",
        "inputs" => [%{"type" => "address", "name" => "newOwner"}],
        "constant" => false
      }

      assert Helper.nonpayable?(function)
    end

    test "returns false when it is payable function" do
      function = %{
        "type" => "function",
        "stateMutability" => "payable",
        "payable" => true,
        "outputs" => [],
        "name" => "upgradeToAndCall",
        "inputs" => [
          %{"type" => "uint256", "name" => "version"},
          %{"type" => "address", "name" => "implementation"},
          %{"type" => "bytes", "name" => "data"}
        ],
        "constant" => false
      }

      refute Helper.nonpayable?(function)
    end

    test "returns true when there is no function" do
      function = %{}

      refute Helper.nonpayable?(function)
    end

    test "returns false when function is nil" do
      function = nil

      refute Helper.nonpayable?(function)
    end
  end

  describe "read_with_wallet_method?" do
    test "doesn't return payable method with output in the read tab" do
      function = %{
        "type" => "function",
        "stateMutability" => "payable",
        "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
        "name" => "returnaddress",
        "inputs" => []
      }

      refute Helper.read_with_wallet_method?(function)
    end

    test "doesn't return payable method with no output in the read tab" do
      function = %{
        "type" => "function",
        "stateMutability" => "payable",
        "outputs" => [],
        "name" => "returnaddress",
        "inputs" => []
      }

      refute Helper.read_with_wallet_method?(function)
    end
  end

  describe "get_binary_string_from_contract_getter/4" do
    # TODO: https://github.com/blockscout/blockscout/issues/12544
    # test "returns bytes starting from 0x" do
    #   abi = [
    #     %{
    #       "type" => "function",
    #       "stateMutability" => "view",
    #       "outputs" => [%{"type" => "bytes16", "name" => "data", "internalType" => "bytes16"}],
    #       "name" => "getData",
    #       "inputs" => []
    #     }
    #   ]

    #   expect(
    #     EthereumJSONRPC.Mox,
    #     :json_rpc,
    #     fn [
    #          %{
    #            id: id,
    #            method: "eth_call",
    #            params: [%{data: "0x3bc5de30", to: "0x0000000000000000000000000000000000000001"}, _]
    #          }
    #        ],
    #        _options ->
    #       {:ok,
    #        [%{id: id, jsonrpc: "2.0", result: "0x3078313233343536373839404142434400000000000000000000000000000000"}]}
    #     end
    #   )

    #   assert "0x30783132333435363738394041424344" ==
    #            Helper.get_binary_string_from_contract_getter(
    #              "3bc5de30",
    #              "0x0000000000000000000000000000000000000001",
    #              abi
    #            )
    # end

    test "returns address" do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "data", "internalType" => "address"}],
          "name" => "getAddress",
          "inputs" => []
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [%{data: "0x38cc4831", to: "0x0000000000000000000000000000000000000001"}, _]
             }
           ],
           _options ->
          {:ok,
           [%{id: id, jsonrpc: "2.0", result: "0x0000000000000000000000003078000000000000000000000000000000000001"}]}
        end
      )

      assert "0x3078000000000000000000000000000000000001" ==
               Helper.get_binary_string_from_contract_getter(
                 "38cc4831",
                 "0x0000000000000000000000000000000000000001",
                 abi
               )
    end
  end

  if Application.compile_env(:explorer, :chain_type) != :zksync do
    describe "fetch_data_for_verification/3" do
      setup do
        resolver_config = Application.get_env(:explorer, CreationDataResolver) || []
        supervisor_config = Application.get_env(:indexer, @internal_transaction_fetcher_supervisor)
        json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

        Application.put_env(:explorer, CreationDataResolver, Keyword.merge(resolver_config, enabled: true))
        Application.put_env(:indexer, @internal_transaction_fetcher_supervisor, disabled?: false)

        # trace by block (`trace_replayBlockTransactions`)
        Application.put_env(:explorer, :json_rpc_named_arguments,
          transport: EthereumJSONRPC.Mox,
          transport_options: [],
          variant: EthereumJSONRPC.Nethermind
        )

        on_exit(fn ->
          Application.put_env(:explorer, CreationDataResolver, resolver_config)
          Application.put_env(:explorer, :json_rpc_named_arguments, json_rpc_named_arguments)

          if is_nil(supervisor_config) do
            Application.delete_env(:indexer, @internal_transaction_fetcher_supervisor)
          else
            Application.put_env(:indexer, @internal_transaction_fetcher_supervisor, supervisor_config)
          end
        end)

        %{address: insert(:contract_address)}
      end

      test "returns creation data with chainId when the creation transaction is in the DB", %{address: address} do
        transaction =
          :transaction
          |> insert(created_contract_address_hash: address.hash)
          |> with_block(status: :ok)

        {creation_input, deployed_bytecode, metadata} =
          Helper.fetch_data_for_verification(address.hash, nil, on_demand?: true)

        assert creation_input == Data.to_string(transaction.input)
        assert deployed_bytecode == Data.to_string(address.contract_code)
        assert Map.has_key?(metadata, "chainId")
        assert metadata["contractAddress"] == to_string(address.hash)
        assert metadata["runtimeCode"] == Data.to_string(address.contract_code)
        assert metadata["blockNumber"] == to_string(transaction.block_number)
        assert metadata["transactionHash"] == to_string(transaction.hash)
        assert metadata["transactionIndex"] == to_string(transaction.index)
        assert metadata["deployer"] == to_string(transaction.from_address_hash)
        assert metadata["creationCode"] == Data.to_string(transaction.input)
      end

      test "keeps chainId and skips discovery on a DB miss when on_demand? is false", %{address: address} do
        {creation_input, _deployed_bytecode, metadata} = Helper.fetch_data_for_verification(address.hash)

        assert is_nil(creation_input)
        assert Map.has_key?(metadata, "chainId")
        assert Enum.all?(@creation_fields, &(not Map.has_key?(metadata, &1)))
      end

      test "omits chainId on a DB miss when on-demand discovery is disabled", %{address: address} do
        Application.put_env(
          :explorer,
          CreationDataResolver,
          Keyword.merge(Application.get_env(:explorer, CreationDataResolver), enabled: false)
        )

        {creation_input, _deployed_bytecode, metadata} =
          Helper.fetch_data_for_verification(address.hash, nil, on_demand?: true)

        assert is_nil(creation_input)
        refute Map.has_key?(metadata, "chainId")
        assert metadata["contractAddress"] == to_string(address.hash)
        assert metadata["runtimeCode"] == Data.to_string(address.contract_code)
        assert Enum.all?(@creation_fields, &(not Map.has_key?(metadata, &1)))
      end

      test "keeps chainId without creation fields for a genesis contract", %{address: address} do
        address_hash_string = to_string(address.hash)

        expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                    %{
                                                      id: id,
                                                      method: "eth_getCode",
                                                      params: [^address_hash_string, "0x0"]
                                                    }
                                                  ],
                                                  _ ->
          {:ok, [%{id: id, result: "0x6080"}]}
        end)

        {creation_input, _deployed_bytecode, metadata} =
          Helper.fetch_data_for_verification(address.hash, nil, on_demand?: true)

        assert is_nil(creation_input)
        assert Map.has_key?(metadata, "chainId")
        assert Enum.all?(@creation_fields, &(not Map.has_key?(metadata, &1)))
      end

      test "returns creation data discovered from the trace with chainId", %{address: address} do
        address_hash_string = to_string(address.hash)
        factory = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
        init = "0x6060604052341561000f57600080fd5b336000806101000a8154"
        now = Timex.now()

        [_, _, _, block, _] =
          Enum.map(0..4, fn number ->
            insert(:block, number: number, timestamp: Timex.shift(now, minutes: number - 10))
          end)

        transaction = :transaction |> insert() |> with_block(block, status: :ok)
        transaction_hash_string = to_string(transaction.hash)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [%{id: id, method: "eth_getCode", params: [^address_hash_string, "0x0"]}], _ ->
          {:ok, [%{id: id, result: "0x"}]}
        end)
        |> expect(:json_rpc, fn [%{id: id, method: "eth_getBlockByNumber", params: ["latest", false]}], _ ->
          {:ok, [%{id: id, result: nil}]}
        end)
        |> expect(:json_rpc, fn %{method: "eth_getTransactionCount", params: [^address_hash_string, "0x2"]}, _ ->
          {:ok, "0x0"}
        end)
        |> expect(:json_rpc, fn %{method: "eth_getTransactionCount", params: [^address_hash_string, "0x3"]}, _ ->
          {:ok, "0x1"}
        end)
        |> expect(:json_rpc, fn requests, _ when is_list(requests) ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_getCode", params: [^address_hash_string, "0x2"]} -> %{id: id, result: "0x"}
             %{id: id, method: "eth_getCode", params: [^address_hash_string, "0x3"]} -> %{id: id, result: "0x6080"}
           end)}
        end)
        |> expect(:json_rpc, fn [%{id: id, method: "trace_replayBlockTransactions", params: ["0x3", ["trace"]]}], _ ->
          {:ok,
           [
             %{
               id: id,
               result: [
                 %{
                   "output" => "0x",
                   "stateDiff" => nil,
                   "trace" => [
                     %{
                       "action" => %{"from" => factory, "gas" => "0x4d0f0", "init" => init, "value" => "0x0"},
                       "result" => %{"address" => address_hash_string, "code" => "0x6080", "gasUsed" => "0x28b6b"},
                       "subtraces" => 0,
                       "traceAddress" => [0],
                       "type" => "create"
                     }
                   ],
                   "transactionHash" => transaction_hash_string,
                   "vmTrace" => nil
                 }
               ]
             }
           ]}
        end)

        {creation_input, _deployed_bytecode, metadata} =
          Helper.fetch_data_for_verification(address.hash, nil, on_demand?: true)

        assert creation_input == init
        assert Map.has_key?(metadata, "chainId")
        assert metadata["blockNumber"] == "3"
        assert metadata["transactionHash"] == transaction_hash_string
        assert metadata["transactionIndex"] == to_string(transaction.index)
        assert metadata["deployer"] == factory
        assert metadata["creationCode"] == init
      end
    end
  end
end
