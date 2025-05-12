defmodule Indexer.Fetcher.InternalTransactionTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import ExUnit.CaptureLog
  import Mox

  alias Ecto.Multi
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, PendingBlockOperation, PendingTransactionOperation}
  alias Explorer.Chain.Import.Runner.Blocks
  alias Indexer.Fetcher.CoinBalance.Catchup, as: CoinBalanceCatchup
  alias Indexer.Fetcher.{InternalTransaction, PendingTransaction, TokenBalance}

  # MUST use global mode because we aren't guaranteed to get PendingTransactionFetcher's pid back fast enough to `allow`
  # it to use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup do
    config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
    Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(config, :block_traceable?, true))

    on_exit(fn -> Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, config) end)
  end

  @moduletag [capture_log: true, no_geth: true]

  test "does not try to fetch pending transactions from Indexer.Fetcher.PendingTransaction", %{
    json_rpc_named_arguments: json_rpc_named_arguments
  } do
    if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
      case Keyword.fetch!(json_rpc_named_arguments, :variant) do
        EthereumJSONRPC.Nethermind ->
          EthereumJSONRPC.Mox
          |> expect(:json_rpc, fn _json, _options ->
            {:ok,
             [
               %{
                 "blockHash" => nil,
                 "blockNumber" => nil,
                 "chainId" => "0x4d",
                 "condition" => nil,
                 "creates" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
                 "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                 "gas" => "0x47b760",
                 "gasPrice" => "0x174876e800",
                 "hash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
                 "input" =>
                   "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
                 "nonce" => "0x0",
                 "publicKey" =>
                   "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
                 "r" => "0xad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75",
                 "raw" =>
                   "0xf9038d8085174876e8008347b7608080b903396060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b002981bda0ad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75a072caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
                 "s" => "0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
                 "standardV" => "0x0",
                 "to" => nil,
                 "transactionIndex" => nil,
                 "v" => "0xbd",
                 "value" => "0x0"
               }
             ]}
          end)
          |> stub(:json_rpc, fn _json, _options ->
            {:ok, []}
          end)

        variant_name ->
          raise ArgumentError, "Unsupported variant name (#{variant_name})"
      end
    end

    CoinBalanceCatchup.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
    PendingTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
    start_token_balance_fetcher(json_rpc_named_arguments)

    wait_for_results(fn ->
      Repo.one!(from(transaction in Explorer.Chain.Transaction, where: is_nil(transaction.block_hash), limit: 1))
    end)

    hash_strings =
      InternalTransaction.init([], fn hash_string, acc -> [hash_string | acc] end, json_rpc_named_arguments)

    assert :ok = InternalTransaction.run(hash_strings, json_rpc_named_arguments)
  end

  @tag :no_geth
  test "marks a block indexed even if no internal transactions are fetched", %{
    json_rpc_named_arguments: json_rpc_named_arguments
  } do
    if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
      case Keyword.fetch!(json_rpc_named_arguments, :variant) do
        EthereumJSONRPC.Nethermind ->
          EthereumJSONRPC.Mox
          |> expect(:json_rpc, fn [%{id: id}], _options ->
            {:ok,
             [
               %{
                 id: id,
                 result: []
               }
             ]}
          end)

        variant_name ->
          raise ArgumentError, "Unsupported variant name (#{variant_name})"
      end
    end

    block_number = 1_000_006
    block = insert(:block, number: block_number)
    insert(:pending_block_operation, block_hash: block.hash, block_number: block.number)

    start_token_balance_fetcher(json_rpc_named_arguments)

    assert :ok = InternalTransaction.run([block_number], json_rpc_named_arguments)

    assert InternalTransaction.init(
             [],
             fn block_number, acc -> [block_number | acc] end,
             json_rpc_named_arguments
           ) == []
  end

  describe "init/2" do
    test "buffers blocks with unfetched internal transactions", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block = insert(:block)
      insert(:pending_block_operation, block_hash: block.hash, block_number: block.number)

      assert InternalTransaction.init(
               [],
               fn block_number, acc -> [block_number | acc] end,
               json_rpc_named_arguments
             ) == [block.number]
    end

    @tag :no_geth
    test "does not buffer blocks with fetched internal transactions", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      insert(:block)

      assert InternalTransaction.init(
               [],
               fn block_number, acc -> [block_number | acc] end,
               json_rpc_named_arguments
             ) == []
    end
  end

  describe "run/2" do
    test "handles empty block numbers", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Nethermind ->
            EthereumJSONRPC.Mox
            |> expect(:json_rpc, fn [%{id: id}], _options ->
              {:ok,
               [
                 %{
                   id: id,
                   result: []
                 }
               ]}
            end)

          EthereumJSONRPC.Geth ->
            # do nothing, this block has no transactions, so Geth shouldn't query
            :ok

          variant_name ->
            raise ArgumentError, "Unsupported variant name (#{variant_name})"
        end
      end

      block = insert(:block)
      block_hash = block.hash
      insert(:pending_block_operation, block_hash: block_hash, block_number: block.number)

      start_token_balance_fetcher(json_rpc_named_arguments)

      assert %{block_hash: block_hash} = Repo.get(PendingBlockOperation, block_hash)

      assert :ok == InternalTransaction.run([block.number], json_rpc_named_arguments)

      assert nil == Repo.get(PendingBlockOperation, block_hash)
    end

    test "handles blocks with transactions correctly", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block = insert(:block)
      transaction = insert(:transaction) |> with_block(block)
      block_hash = block.hash
      insert(:pending_block_operation, block_hash: block_hash, block_number: block.number)

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Nethermind ->
            EthereumJSONRPC.Mox
            |> expect(:json_rpc, fn [%{id: id, method: "trace_replayBlockTransactions"}], _options ->
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
                           "action" => %{
                             "callType" => "call",
                             "from" => "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
                             "gas" => "0x8600",
                             "input" => "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
                             "to" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
                             "value" => "0x174876e800"
                           },
                           "result" => %{"gasUsed" => "0x7d37", "output" => "0x"},
                           "subtraces" => 1,
                           "traceAddress" => [],
                           "type" => "call"
                         },
                         %{
                           "action" => %{
                             "callType" => "call",
                             "from" => "0xb37b428a7ddee91f39b26d79d23dc1c89e3e12a7",
                             "gas" => "0x32dcf",
                             "input" => "0x42dad49e",
                             "to" => "0xee4019030fb5c2b68c42105552c6268d56c6cbfe",
                             "value" => "0x0"
                           },
                           "result" => %{
                             "gasUsed" => "0xb08",
                             "output" => "0x"
                           },
                           "subtraces" => 0,
                           "traceAddress" => [0],
                           "type" => "call"
                         }
                       ],
                       "transactionHash" => transaction.hash,
                       "vmTrace" => nil
                     }
                   ]
                 }
               ]}
            end)

          EthereumJSONRPC.Geth ->
            EthereumJSONRPC.Mox
            |> expect(:json_rpc, fn [%{id: id, method: "debug_traceTransaction"}], _options ->
              {:ok,
               [
                 %{
                   id: id,
                   result: [
                     %{
                       "blockNumber" => block.number,
                       "transactionIndex" => 0,
                       "transactionHash" => transaction.hash,
                       "index" => 0,
                       "traceAddress" => [],
                       "type" => "call",
                       "callType" => "call",
                       "from" => "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
                       "to" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
                       "gas" => "0x8600",
                       "gasUsed" => "0x7d37",
                       "input" => "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
                       "output" => "0x",
                       "value" => "0x174876e800"
                     }
                   ]
                 }
               ]}
            end)

          variant_name ->
            raise ArgumentError, "Unsupported variant name (#{variant_name})"
        end
      end

      CoinBalanceCatchup.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      start_token_balance_fetcher(json_rpc_named_arguments)

      assert %{block_hash: block_hash} = Repo.get(PendingBlockOperation, block_hash)

      assert :ok == InternalTransaction.run([block.number], json_rpc_named_arguments)

      assert nil == Repo.get(PendingBlockOperation, block_hash)

      assert Repo.exists?(from(i in Chain.InternalTransaction, where: i.block_hash == ^block_hash))
    end

    test "handles failure by retrying only unique numbers", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, [%{id: 0, error: %{code: -32602, message: "Invalid params"}}]}
        end)
      end

      block = insert(:block)
      insert(:transaction) |> with_block(block)
      block_hash = block.hash
      insert(:pending_block_operation, block_hash: block_hash, block_number: block.number)

      assert %{block_hash: ^block_hash} = Repo.get(PendingBlockOperation, block_hash)

      assert {:retry, [block.number]} == InternalTransaction.run([block.number, block.number], json_rpc_named_arguments)

      assert %{block_hash: ^block_hash} = Repo.get(PendingBlockOperation, block_hash)
    end

    test "set block refetch_needed=true on foreign_key_violation", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block = insert(:block)
      transaction = :transaction |> insert() |> with_block(block)
      block_number = block.number
      insert(:pending_block_operation, block_hash: block.hash, block_number: block.number)

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Nethermind ->
            EthereumJSONRPC.Mox
            |> expect(:json_rpc, fn [%{id: id, method: "trace_replayBlockTransactions"}], _options ->
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
                           "action" => %{
                             "callType" => "call",
                             "from" => "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
                             "gas" => "0x8600",
                             "input" => "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
                             "to" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
                             "value" => "0x174876e800"
                           },
                           "result" => %{"gasUsed" => "0x7d37", "output" => "0x"},
                           "subtraces" => 1,
                           "traceAddress" => [],
                           "type" => "call"
                         },
                         %{
                           "action" => %{
                             "callType" => "call",
                             "from" => "0xb37b428a7ddee91f39b26d79d23dc1c89e3e12a7",
                             "gas" => "0x32dcf",
                             "input" => "0x42dad49e",
                             "to" => "0xee4019030fb5c2b68c42105552c6268d56c6cbfe",
                             "value" => "0x0"
                           },
                           "result" => %{
                             "gasUsed" => "0xb08",
                             "output" => "0x"
                           },
                           "subtraces" => 0,
                           "traceAddress" => [0],
                           "type" => "call"
                         }
                       ],
                       "transactionHash" => transaction.hash,
                       "vmTrace" => nil
                     },
                     %{
                       "output" => "0x",
                       "stateDiff" => nil,
                       "trace" => [
                         %{
                           "action" => %{
                             "callType" => "call",
                             "from" => "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
                             "gas" => "0x8600",
                             "input" => "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
                             "to" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
                             "value" => "0x174876e800"
                           },
                           "result" => %{"gasUsed" => "0x7d37", "output" => "0x"},
                           "subtraces" => 1,
                           "traceAddress" => [],
                           "type" => "call"
                         },
                         %{
                           "action" => %{
                             "callType" => "call",
                             "from" => "0xb37b428a7ddee91f39b26d79d23dc1c89e3e12a7",
                             "gas" => "0x32dcf",
                             "input" => "0x42dad49e",
                             "to" => "0xee4019030fb5c2b68c42105552c6268d56c6cbfe",
                             "value" => "0x0"
                           },
                           "result" => %{
                             "gasUsed" => "0xb08",
                             "output" => "0x"
                           },
                           "subtraces" => 0,
                           "traceAddress" => [0],
                           "type" => "call"
                         }
                       ],
                       "transactionHash" => transaction_hash(),
                       "vmTrace" => nil
                     }
                   ]
                 }
               ]}
            end)

          EthereumJSONRPC.Geth ->
            EthereumJSONRPC.Mox
            |> expect(:json_rpc, fn [%{id: id, method: "debug_traceTransaction"}], _options ->
              {:ok,
               [
                 %{
                   id: id,
                   result: [
                     %{
                       "blockNumber" => block.number,
                       "transactionIndex" => 0,
                       "transactionHash" => transaction.hash,
                       "index" => 0,
                       "traceAddress" => [],
                       "type" => "call",
                       "callType" => "call",
                       "from" => "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
                       "to" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
                       "gas" => "0x8600",
                       "gasUsed" => "0x7d37",
                       "input" => "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
                       "output" => "0x",
                       "value" => "0x174876e800"
                     },
                     %{
                       "blockNumber" => block.number,
                       "transactionIndex" => 0,
                       "transactionHash" => transaction_hash(),
                       "index" => 0,
                       "traceAddress" => [],
                       "type" => "call",
                       "callType" => "call",
                       "from" => "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
                       "to" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
                       "gas" => "0x8600",
                       "gasUsed" => "0x7d37",
                       "input" => "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
                       "output" => "0x",
                       "value" => "0x174876e800"
                     }
                   ]
                 }
               ]}
            end)

          variant_name ->
            raise ArgumentError, "Unsupported variant name (#{variant_name})"
        end
      end

      logs =
        capture_log(fn ->
          assert {:retry, [^block_number]} = InternalTransaction.run([block_number], json_rpc_named_arguments)
        end)

      assert %{consensus: true, refetch_needed: true} = Repo.reload(block)
      assert logs =~ "foreign_key_violation on internal transactions import, foreign transactions hashes:"
    end
  end

  test "doesn't delete pending block operations after block import if no async process was requested", %{
    json_rpc_named_arguments: json_rpc_named_arguments
  } do
    fetcher_options =
      Keyword.merge([poll: true, json_rpc_named_arguments: json_rpc_named_arguments], InternalTransaction.defaults())

    if fetcher_options[:poll] do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id}], _options ->
        {:ok, [%{id: id, result: []}]}
      end)
    end

    InternalTransaction.Supervisor.Case.start_supervised!(fetcher_options)

    %Ecto.Changeset{valid?: true, changes: block_changes} =
      Block.changeset(%Block{}, params_for(:block, miner_hash: insert(:address).hash, number: 1))

    changes_list = [block_changes]
    timestamp = DateTime.utc_now()
    options = %{timestamps: %{inserted_at: timestamp, updated_at: timestamp}}

    assert [] = Repo.all(PendingBlockOperation)

    {:ok, %{blocks: [%{number: block_number, hash: block_hash}]}} =
      Multi.new()
      |> Blocks.run(changes_list, options)
      |> Repo.transaction()

    assert %{block_number: ^block_number, block_hash: ^block_hash} = Repo.one(PendingBlockOperation)

    Process.sleep(4000)

    assert %{block_number: ^block_number, block_hash: ^block_hash} = Repo.one(PendingBlockOperation)
  end

  if Application.compile_env(:explorer, :chain_type) == :arbitrum do
    test "fetches internal transactions from Arbitrum", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(config, :block_traceable?, false))

      json_rpc_named_arguments =
        json_rpc_named_arguments
        |> Enum.reject(fn {key, _value} -> key == :variant || key == :transport_options end)
        |> Enum.concat([{:variant, EthereumJSONRPC.Geth}])
        |> Enum.concat([{:transport_options, [http_options: []]}])

      block = insert(:block, number: 1)
      _transaction = :transaction |> insert() |> with_block(block)
      block_number = block.number
      block_hash = block.hash
      insert(:pending_block_operation, block_hash: block_hash, block_number: block_number)

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: id, method: "debug_traceTransaction"}], _options ->
        {:ok,
         [
           %{
             id: id,
             result: %{
               "afterEVMTransfers" => [],
               "beforeEVMTransfers" => [],
               "calls" => [
                 %{
                   "from" => "0x0000000000000000000000000000000000000000",
                   "gas" => "0x0",
                   "gasUsed" => "0x0",
                   "input" => "0x",
                   "to" => "0x888f05d02ea7b42f32f103c089c1750170830642",
                   "type" => "INVALID",
                   "value" => "0xbf676993d52eb8bfe"
                 },
                 %{
                   "from" => "0x888f05d02ea7b42f32f103c089c1750170830642",
                   "gas" => "0x0",
                   "gasUsed" => "0x0",
                   "input" => "0x",
                   "to" => "0x6cbb552855ce5eb70af49b76a8048be8e3799a05",
                   "type" => "INVALID",
                   "value" => "0x0"
                 },
                 %{
                   "from" => "0x888f05d02ea7b42f32f103c089c1750170830642",
                   "gas" => "0x0",
                   "gasUsed" => "0x0",
                   "input" => "0x",
                   "to" => "0xfdaf8f210d52a3f8ee416ad06ff4a0868bb649d4",
                   "type" => "INVALID",
                   "value" => "0x64425bdf7e3fc6462"
                 },
                 %{
                   "from" => "0x888f05d02ea7b42f32f103c089c1750170830642",
                   "gas" => "0x0",
                   "gasUsed" => "0x0",
                   "input" => "0x",
                   "to" => "0xbeb639f6ac1e9ca8a4badb4e0f888fd150c042cb",
                   "type" => "INVALID",
                   "value" => "0x5b250db3e722b43fc"
                 },
                 %{
                   "from" => "0x888f05d02ea7b42f32f103c089c1750170830642",
                   "gas" => "0x0",
                   "gasUsed" => "0x0",
                   "input" => "0x",
                   "to" => "0xfdaf8f210d52a3f8ee416ad06ff4a0868bb649d4",
                   "type" => "INVALID",
                   "value" => "0x6fcc3e3a0"
                 }
               ],
               "from" => "0x888f05d02ea7b42f32f103c089c1750170830642",
               "gas" => "0x0",
               "gasUsed" => "0x0",
               "input" =>
                 "0xc9f95d32000000000000000000000000000000000000000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bf676993d52eb8bfe000000000000000000000000000000000000000000000005b250db3e722b43fc00000000000000000000000000000000000000000000000000000000000f439e00000000000000000000000000000000000000000000000000000000000075300000000000000000000000000000000000000000000000064425bdf7e3fc6462000000000000000000000000fdaf8f210d52a3f8ee416ad06ff4a0868bb649d4000000000000000000000000fdaf8f210d52a3f8ee416ad06ff4a0868bb649d4000000000000000000000000fdaf8f210d52a3f8ee416ad06ff4a0868bb649d400000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000",
               "to" => "0x000000000000000000000000000000000000006e",
               "type" => "CALL",
               "value" => "0x0"
             }
           }
         ]}
      end)

      CoinBalanceCatchup.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      assert %{block_hash: block_hash} = Repo.get(PendingBlockOperation, block_hash)

      assert :ok == InternalTransaction.run([block_number], json_rpc_named_arguments)

      assert nil == Repo.get(PendingBlockOperation, block_hash)

      internal_transactions = Repo.all(from(i in Chain.InternalTransaction, where: i.block_hash == ^block_hash))

      assert Enum.count(internal_transactions) > 0

      last_internal_transaction = List.last(internal_transactions)

      assert last_internal_transaction.type == :call
      assert last_internal_transaction.call_type == :invalid
    end
  end

  # Due to token-duality feature in Celo network (native coin transfers are
  # treated as token transfers), we need to fetch updated token balances after
  # parsing the internal transactions
  if Application.compile_env(:explorer, :chain_type) == :celo do
    defp start_token_balance_fetcher(json_rpc_named_arguments) do
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
    end
  else
    defp start_token_balance_fetcher(_json_rpc_named_arguments), do: :ok
  end
end
