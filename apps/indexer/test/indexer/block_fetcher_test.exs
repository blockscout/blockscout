defmodule Indexer.BlockFetcherTest do
  # `async: false` due to use of named GenServer
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import ExUnit.CaptureLog
  import Mox
  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  import EthereumJSONRPC.Case

  alias Explorer.Chain.{Address, Block, Log, Transaction, Wei}

  alias Indexer.{
    AddressBalanceFetcher,
    AddressBalanceFetcherCase,
    BlockFetcher,
    BufferedTask,
    InternalTransactionFetcher,
    InternalTransactionFetcherCase,
    Sequence
  }

  @moduletag capture_log: true

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  # First block with all schemas to import
  # 37 is determined using the following query:
  # SELECT MIN(blocks.number) FROM
  # (SELECT blocks.number
  #  FROM internal_transactions
  #  INNER JOIN transactions
  #  ON transactions.hash = internal_transactions.transaction_hash
  #  INNER JOIN blocks
  #  ON blocks.hash = transactions.block_hash
  #  INTERSECT
  #  SELECT blocks.number
  #  FROM logs
  #  INNER JOIN transactions
  #  ON transactions.hash = logs.transaction_hash
  #  INNER JOIN blocks
  #  ON blocks.hash = transactions.block_hash) as blocks
  @first_full_block_number 37

  describe "start_link/1" do
    test "starts fetching blocks from latest and goes down", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Parity ->
            block_number = 3_416_888
            block_quantity = integer_to_quantity(block_number)

            EthereumJSONRPC.Mox
            |> stub(:json_rpc, fn
              # latest block number to seed starting block number for genesis and realtime tasks
              %{method: "eth_getBlockByNumber", params: ["latest", false]}, _options ->
                {:ok,
                 %{
                   "author" => "0xe2ac1c6843a33f81ae4935e5ef1277a392990381",
                   "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                   "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
                   "gasLimit" => "0x7a1200",
                   "gasUsed" => "0x0",
                   "hash" => "0x627baabf5a17c0cfc547b6903ac5e19eaa91f30d9141be1034e3768f6adbc94e",
                   "logsBloom" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                   "miner" => "0xe2ac1c6843a33f81ae4935e5ef1277a392990381",
                   "number" => block_quantity,
                   "parentHash" => "0x006edcaa1e6fde822908783bc4ef1ad3675532d542fce53537557391cfe34c3c",
                   "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "sealFields" => [
                     "0x841240b30d",
                     "0xb84158bc4fa5891934bc94c5dca0301867ce4f35925ef46ea187496162668210bba61b4cda09d7e0dca2f1dd041fad498ced6697aeef72656927f52c55b630f2591c01"
                   ],
                   "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                   "signature" =>
                     "58bc4fa5891934bc94c5dca0301867ce4f35925ef46ea187496162668210bba61b4cda09d7e0dca2f1dd041fad498ced6697aeef72656927f52c55b630f2591c01",
                   "size" => "0x243",
                   "stateRoot" => "0x9a8111062667f7b162851a1cbbe8aece5ff12e761b3dcee93b787fcc12548cf7",
                   "step" => "306230029",
                   "timestamp" => "0x5b437f41",
                   "totalDifficulty" => "0x342337ffffffffffffffffffffffffed8d29bb",
                   "transactions" => [],
                   "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "uncles" => []
                 }}

              [%{method: "eth_getBlockByNumber", params: [_, true]} | _] = requests, _options ->
                {:ok,
                 Enum.map(requests, fn %{id: id, params: [block_quantity, true]} ->
                   %{
                     id: id,
                     jsonrpc: "2.0",
                     result: %{
                       "author" => "0xe2ac1c6843a33f81ae4935e5ef1277a392990381",
                       "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                       "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
                       "gasLimit" => "0x7a1200",
                       "gasUsed" => "0x0",
                       "hash" =>
                         Explorer.Factory.block_hash()
                         |> to_string(),
                       "logsBloom" =>
                         "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                       "miner" => "0xe2ac1c6843a33f81ae4935e5ef1277a392990381",
                       "number" => block_quantity,
                       "parentHash" =>
                         Explorer.Factory.block_hash()
                         |> to_string(),
                       "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                       "sealFields" => [
                         "0x841240b30d",
                         "0xb84158bc4fa5891934bc94c5dca0301867ce4f35925ef46ea187496162668210bba61b4cda09d7e0dca2f1dd041fad498ced6697aeef72656927f52c55b630f2591c01"
                       ],
                       "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                       "signature" =>
                         "58bc4fa5891934bc94c5dca0301867ce4f35925ef46ea187496162668210bba61b4cda09d7e0dca2f1dd041fad498ced6697aeef72656927f52c55b630f2591c01",
                       "size" => "0x243",
                       "stateRoot" => "0x9a8111062667f7b162851a1cbbe8aece5ff12e761b3dcee93b787fcc12548cf7",
                       "step" => "306230029",
                       "timestamp" => "0x5b437f41",
                       "totalDifficulty" => "0x342337ffffffffffffffffffffffffed8d29bb",
                       "transactions" => [],
                       "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                       "uncles" => []
                     }
                   }
                 end)}

              [%{method: "eth_getBalance"} | _] = requests, _options ->
                {:ok, Enum.map(requests, fn %{id: id} -> %{id: id, jsonrpc: "2.0", result: "0x0"} end)}
            end)

          EthereumJSONRPC.Geth ->
            block_number = 5_950_901
            block_quantity = integer_to_quantity(block_number)

            EthereumJSONRPC.Mox
            |> stub(:json_rpc, fn
              %{method: "eth_getBlockByNumber", params: ["latest", false]}, _options ->
                {:ok,
                 %{
                   "difficulty" => "0xc2550dc5bfc5d",
                   "extraData" => "0x65746865726d696e652d657538",
                   "gasLimit" => "0x7a121d",
                   "gasUsed" => "0x6cc04b",
                   "hash" => "0x71f484056fec687fd469989426c94c469ff08a28eae9a1865359d64557bb99f6",
                   "logsBloom" =>
                     "0x900840000041000850020000002800020800840900200210041006005028810880231200c1a0800001003a00011813005102000020800207080210000020014c00888640001040300c180008000084001000010018010040001118181400a06000280428024010081100015008080814141000644404040a8021101010040001001022000000000880420004008000180004000a01002080890010000a0601001a0000410244421002c0000100920100020004000020c10402004080008000203001000200c4001a000002000c0000000100200410090bc52e080900108230000110010082120200000004e01002000500001009e14001002051000040830080",
                   "miner" => "0xea674fdde714fd979de3edf0f56aa9716b898ec8",
                   "mixHash" => "0x555275cd0ab4c3b2fe3936843ee25bb67da05ef7dcf17216bc0e382d21d139a0",
                   "nonce" => "0xa49e42a024600113",
                   "number" => block_quantity,
                   "parentHash" => "0xb4357733c59cc6f785542d072a205f4e195f7198f544ea5e01c1b90ef0f914a5",
                   "receiptsRoot" => "0x17baf8de366fecc1be494bff245be6357ac60a5fe786099dba89983778c8421e",
                   "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                   "size" => "0x6c7b",
                   "stateRoot" => "0x79345c692a0bf363e95c37750336c534309b3f3fe8b59712ac1527118070f488",
                   "timestamp" => "0x5b475377",
                   "totalDifficulty" => "0x120258e22c69502fc88",
                   "transactions" => ["0xa4b58d1d1473f4891d9ff91f624dba73611bf1f6e9a60d3ca2dcfc75d2ab185c"],
                   "transactionsRoot" => "0x5972b7988f667d7e86679322641117e503ea2c1bc5a27822a8a8120fe53f2c8b",
                   "uncles" => []
                 }}

              [%{method: "eth_getBlockByNumber", params: [_, true]} | _] = requests, _options ->
                {:ok,
                 Enum.map(requests, fn %{id: id, params: [block_quantity, true]} ->
                   %{
                     id: id,
                     jsonrpc: "2.0",
                     result: %{
                       "difficulty" => "0xc22479024e55f",
                       "extraData" => "0x73656f3130",
                       "gasLimit" => "0x7a121d",
                       "gasUsed" => "0x7a0527",
                       "hash" =>
                         Explorer.Factory.block_hash()
                         |> to_string(),
                       "logsBloom" =>
                         "0x006a044c050a6759208088200009808898246808402123144ac15801c09a2672990130000042500000cc6090b063f195352095a88018194112101a02640000a0109c03c40568440b853a800a60044408604bb49d1d604c802008000884520208496608a520992e0f4b41a94188088920c1995107db4696c03839a911500084001009884100605084c4542953b08101103080254c34c802a00042a62f811340400d22080d000c0e39927ca481800c8024048425462000150850500205a224810041904023a80c00dc01040203000086020111210403081096822008c12500a2060a54834800400851210122c481a04a24b5284e9900a08110c180011001c03100",
                       "miner" => "0xb2930b35844a230f00e51431acae96fe543a0347",
                       "mixHash" => "0x5e07a58028d2cee7ddbefe245e6d7b5232d997b66cc906b18ad9ad51535ced24",
                       "nonce" => "0x3d88ebe8031aadf6",
                       "number" => block_quantity,
                       "parentHash" =>
                         Explorer.Factory.block_hash()
                         |> to_string(),
                       "receiptsRoot" => "0x5294a8b56be40c0c198aa443664e801bb926d49878f96151849f3ddd0cb5e76d",
                       "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                       "size" => "0x4796",
                       "stateRoot" => "0x3755d4b5c9ae3cd58d7a856a46fbe8fb69f0ba93d81e831cd68feb8b61bc3009",
                       "timestamp" => "0x5b475393",
                       "totalDifficulty" => "0x120259a450e2527e1e7",
                       "transactions" => [],
                       "transactionsRoot" => "0xa71969ed649cd1f21846ab7b4029e79662941cc34cd473aa4590e666920ad2f4",
                       "uncles" => []
                     }
                   }
                 end)}

              [%{method: "eth_getBalance"} | _] = requests, _options ->
                {:ok, Enum.map(requests, fn %{id: id} -> %{id: id, jsonrpc: "2.0", result: "0x0"} end)}
            end)

          variant_name ->
            raise ArgumentError, "Unsupported variant name (#{variant_name})"
        end
      end

      {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)

      default_blocks_batch_size = BlockFetcher.default_blocks_batch_size()

      assert latest_block_number > default_blocks_batch_size

      assert Repo.aggregate(Block, :count, :hash) == 0

      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransactionFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      start_supervised!({BlockFetcher, json_rpc_named_arguments: json_rpc_named_arguments})

      wait_for_results(fn ->
        Repo.one!(from(block in Block, where: block.number == ^latest_block_number))
      end)

      assert Repo.aggregate(Block, :count, :hash) >= 1

      previous_batch_block_number = latest_block_number - default_blocks_batch_size

      wait_for_results(fn ->
        Repo.one!(from(block in Block, where: block.number == ^previous_batch_block_number))
      end)

      assert Repo.aggregate(Block, :count, :hash) >= default_blocks_batch_size
    end
  end

  describe "handle_info(:debug_count, state)" do
    setup :state

    setup do
      block = insert(:block)

      Enum.map(0..2, fn _ ->
        transaction =
          :transaction
          |> insert()
          |> with_block(block)

        insert(:log, transaction: transaction)
        insert(:internal_transaction, transaction: transaction, index: 0)
      end)

      :ok
    end

    @tag :capture_log
    @heading "persisted counts"
    test "without debug_logs", %{json_rpc_named_arguments: json_rpc_named_arguments, state: state} do
      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransactionFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      wait_for_tasks(InternalTransactionFetcher)
      wait_for_tasks(AddressBalanceFetcher)

      refute capture_log_at_level(:debug, fn ->
               Indexer.disable_debug_logs()
               BlockFetcher.handle_info(:debug_count, state)
             end) =~ @heading
    end

    @tag :capture_log
    test "with debug_logs", %{json_rpc_named_arguments: json_rpc_named_arguments, state: state} do
      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransactionFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      wait_for_tasks(InternalTransactionFetcher)
      wait_for_tasks(AddressBalanceFetcher)

      log =
        capture_log_at_level(:debug, fn ->
          Indexer.enable_debug_logs()
          BlockFetcher.handle_info(:debug_count, state)
        end)

      assert log =~ @heading
      assert log =~ "blocks: 1"
      assert log =~ "internal transactions: 3"
      assert log =~ "logs: 3"
      assert log =~ "addresses: 16"
    end
  end

  describe "import_range/3" do
    setup :state

    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransactionFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      {:ok, state} = BlockFetcher.init(json_rpc_named_arguments: json_rpc_named_arguments)

      %{state: state}
    end

    test "with single element range that is valid imports one block", %{
      json_rpc_named_arguments: json_rpc_named_arguments,
      state: state
    } do
      block_number = 0

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        block_quantity = integer_to_quantity(block_number)
        miner_hash = "0x0000000000000000000000000000000000000000"

        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Parity ->
            EthereumJSONRPC.Mox
            |> expect(:json_rpc, fn [%{id: id, method: "eth_getBlockByNumber", params: [^block_quantity, true]}],
                                    _options ->
              {:ok,
               [
                 %{
                   id: id,
                   jsonrpc: "2.0",
                   result: %{
                     "author" => "0x0000000000000000000000000000000000000000",
                     "difficulty" => "0x20000",
                     "extraData" => "0x",
                     "gasLimit" => "0x663be0",
                     "gasUsed" => "0x0",
                     "hash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
                     "logsBloom" =>
                       "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                     "miner" => miner_hash,
                     "number" => block_quantity,
                     "parentHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
                     "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                     "sealFields" => [
                       "0x80",
                       "0xb8410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
                     ],
                     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                     "signature" =>
                       "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                     "size" => "0x215",
                     "stateRoot" => "0xfad4af258fd11939fae0c6c6eec9d340b1caac0b0196fd9a1bc3f489c5bf00b3",
                     "step" => "0",
                     "timestamp" => "0x0",
                     "totalDifficulty" => "0x20000",
                     "transactions" => [],
                     "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                     "uncles" => []
                   }
                 }
               ]}
            end)
            |> expect(:json_rpc, fn [
                                      %{
                                        id: id,
                                        jsonrpc: "2.0",
                                        method: "eth_getBalance",
                                        params: [^miner_hash, ^block_quantity]
                                      }
                                    ],
                                    _options ->
              {:ok, [%{id: id, jsonrpc: "2.0", result: "0x0"}]}
            end)

          EthereumJSONRPC.Geth ->
            EthereumJSONRPC.Mox
            |> expect(:json_rpc, fn [%{id: id, method: "eth_getBlockByNumber", params: [^block_quantity, true]}],
                                    _options ->
              {:ok,
               [
                 %{
                   id: id,
                   jsonrpc: "2.0",
                   result: %{
                     "difficulty" => "0x400000000",
                     "extraData" => "0x11bbe8db4e347b4e8c937c1c8370e4b5ed33adb3db69cbdb7a38e1e50b1b82fa",
                     "gasLimit" => "0x1388",
                     "gasUsed" => "0x0",
                     "hash" => "0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3",
                     "logsBloom" =>
                       "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                     "miner" => miner_hash,
                     "mixHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
                     "nonce" => "0x0000000000000042",
                     "number" => block_quantity,
                     "parentHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
                     "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                     "size" => "0x21c",
                     "stateRoot" => "0xd7f8974fb5ac78d9ac099b9ad5018bedc2ce0a72dad1827a1709da30580f0544",
                     "timestamp" => "0x0",
                     "totalDifficulty" => "0x400000000",
                     "transactions" => [],
                     "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                     "uncles" => []
                   }
                 }
               ]}
            end)
            |> expect(:json_rpc, fn [
                                      %{
                                        id: id,
                                        jsonrpc: "2.0",
                                        method: "eth_getBalance",
                                        params: [^miner_hash, ^block_quantity]
                                      }
                                    ],
                                    _options ->
              {:ok, [%{id: id, jsonrpc: "2.0", result: "0x0"}]}
            end)

          variant_name ->
            raise ArgumentError, "Unsupported variant name (#{variant_name})"
        end
      end

      {:ok, sequence} = Sequence.start_link(first: 0, step: 1)

      %{address_hash: address_hash, block_hash: block_hash} =
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Geth ->
            %{
              address_hash: %Explorer.Chain.Hash{
                byte_count: 20,
                bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
              },
              block_hash: %Explorer.Chain.Hash{
                byte_count: 32,
                bytes:
                  <<212, 229, 103, 64, 248, 118, 174, 248, 192, 16, 184, 106, 64, 213, 245, 103, 69, 161, 24, 208, 144,
                    106, 52, 230, 154, 236, 140, 13, 177, 203, 143, 163>>
              }
            }

          EthereumJSONRPC.Parity ->
            %{
              address_hash: %Explorer.Chain.Hash{
                byte_count: 20,
                bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
              },
              block_hash: %Explorer.Chain.Hash{
                byte_count: 32,
                bytes:
                  <<91, 40, 193, 191, 211, 161, 82, 48, 201, 164, 107, 57, 156, 208, 249, 166, 146, 13, 67, 46, 133, 56,
                    28, 198, 161, 64, 176, 110, 132, 16, 17, 47>>
              }
            }

          variant ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end

      log_bad_gateway(
        fn -> BlockFetcher.import_range(block_number..block_number, state, sequence) end,
        fn result ->
          assert {:ok,
                  %{
                    addresses: [^address_hash],
                    blocks: [^block_hash],
                    logs: [],
                    transactions: []
                  }} = result

          wait_for_tasks(InternalTransactionFetcher)
          wait_for_tasks(AddressBalanceFetcher)

          assert Repo.aggregate(Block, :count, :hash) == 1
          assert Repo.aggregate(Address, :count, :hash) == 1

          address = Repo.get!(Address, address_hash)

          assert address.fetched_balance == %Wei{value: Decimal.new(0)}
          assert address.fetched_balance_block_number == 0
        end
      )
    end

    # We can't currently index the whole Ethereum Mainnet, so we don't know what is the first full block.
    #   Implement when a full block is found for Ethereum Mainnet and remove :no_geth tag
    @tag :no_geth
    test "can import range with all synchronous imported schemas", %{
      json_rpc_named_arguments: json_rpc_named_arguments,
      state: state
    } do
      block_number = @first_full_block_number

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Parity ->
            block_quantity = integer_to_quantity(block_number)
            from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
            to_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
            transaction_hash = "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"

            EthereumJSONRPC.Mox
            |> expect(:json_rpc, fn json, _options ->
              assert [%{id: id, method: "eth_getBlockByNumber", params: [^block_quantity, true]}] = json

              {:ok,
               [
                 %{
                   id: id,
                   jsonrpc: "2.0",
                   result: %{
                     "author" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                     "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                     "extraData" => "0xd5830108048650617269747986312e32322e31826c69",
                     "gasLimit" => "0x69fe20",
                     "gasUsed" => "0xc512",
                     "hash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                     "logsBloom" =>
                       "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                     "miner" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                     "number" => "0x25",
                     "parentHash" => "0xc37bbad7057945d1bf128c1ff009fb1ad632110bf6a000aac025a80f7766b66e",
                     "receiptsRoot" => "0xd300311aab7dcc98c05ac3f1893629b2c9082c189a0a0c76f4f63e292ac419d5",
                     "sealFields" => [
                       "0x84120a71de",
                       "0xb841fcdb570511ec61edda93849bb7c6b3232af60feb2ea74e4035f0143ab66dfdd00f67eb3eda1adddbb6b572db1e0abd39ce00f9b3ccacb9f47973279ff306fe5401"
                     ],
                     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                     "signature" =>
                       "fcdb570511ec61edda93849bb7c6b3232af60feb2ea74e4035f0143ab66dfdd00f67eb3eda1adddbb6b572db1e0abd39ce00f9b3ccacb9f47973279ff306fe5401",
                     "size" => "0x2cf",
                     "stateRoot" => "0x2cd84079b0d0c267ed387e3895fd1c1dc21ff82717beb1132adac64276886e19",
                     "step" => "302674398",
                     "timestamp" => "0x5a343956",
                     "totalDifficulty" => "0x24ffffffffffffffffffffffffedf78dfd",
                     "transactions" => [
                       %{
                         "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                         "blockNumber" => "0x25",
                         "chainId" => "0x4d",
                         "condition" => nil,
                         "creates" => nil,
                         "from" => from_address_hash,
                         "gas" => "0x47b760",
                         "gasPrice" => "0x174876e800",
                         "hash" => transaction_hash,
                         "input" => "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                         "nonce" => "0x4",
                         "publicKey" =>
                           "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
                         "r" => "0xa7f8f45cce375bb7af8750416e1b03e0473f93c256da2285d1134fc97a700e01",
                         "raw" =>
                           "0xf88a0485174876e8008347b760948bf38d4764929064f2d4d3a56520a76ab3df415b80a410855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef81bea0a7f8f45cce375bb7af8750416e1b03e0473f93c256da2285d1134fc97a700e01a01f87a076f13824f4be8963e3dffd7300dae64d5f23c9a062af0c6ead347c135f",
                         "s" => "0x1f87a076f13824f4be8963e3dffd7300dae64d5f23c9a062af0c6ead347c135f",
                         "standardV" => "0x1",
                         "to" => to_address_hash,
                         "transactionIndex" => "0x0",
                         "v" => "0xbe",
                         "value" => "0x0"
                       }
                     ],
                     "transactionsRoot" => "0x68e314a05495f390f9cd0c36267159522e5450d2adf254a74567b452e767bf34",
                     "uncles" => []
                   }
                 }
               ]}
            end)
            |> expect(:json_rpc, fn json, _options ->
              assert [
                       %{
                         id: id,
                         method: "eth_getTransactionReceipt",
                         params: ["0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"]
                       }
                     ] = json

              {:ok,
               [
                 %{
                   id: id,
                   jsonrpc: "2.0",
                   result: %{
                     "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                     "blockNumber" => "0x25",
                     "contractAddress" => nil,
                     "cumulativeGasUsed" => "0xc512",
                     "gasUsed" => "0xc512",
                     "logs" => [
                       %{
                         "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
                         "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                         "blockNumber" => "0x25",
                         "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                         "logIndex" => "0x0",
                         "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
                         "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                         "transactionIndex" => "0x0",
                         "transactionLogIndex" => "0x0",
                         "type" => "mined"
                       }
                     ],
                     "logsBloom" =>
                       "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                     "root" => nil,
                     "status" => "0x1",
                     "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                     "transactionIndex" => "0x0"
                   }
                 }
               ]}
            end)
            # async requests need to be grouped in one expect because the order is non-deterministic while multiple expect
            # calls on the same name/arity are used in order
            |> expect(:json_rpc, 5, fn json, _options ->
              [request] = json

              case request do
                %{id: id, method: "eth_getBalance", params: [^to_address_hash, ^block_quantity]} ->
                  {:ok, [%{id: id, jsonrpc: "2.0", result: "0x1"}]}

                %{id: id, method: "eth_getBalance", params: [^from_address_hash, ^block_quantity]} ->
                  {:ok, [%{id: id, jsonrpc: "2.0", result: "0xd0d4a965ab52d8cd740000"}]}

                %{id: id, method: "trace_replayTransaction", params: [^transaction_hash, ["trace"]]} ->
                  {:ok,
                   [
                     %{
                       id: id,
                       jsonrpc: "2.0",
                       result: %{
                         "output" => "0x",
                         "stateDiff" => nil,
                         "trace" => [
                           %{
                             "action" => %{
                               "callType" => "call",
                               "from" => from_address_hash,
                               "gas" => "0x475ec8",
                               "input" => "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                               "to" => to_address_hash,
                               "value" => "0x0"
                             },
                             "result" => %{"gasUsed" => "0x6c7a", "output" => "0x"},
                             "subtraces" => 0,
                             "traceAddress" => [],
                             "type" => "call"
                           }
                         ],
                         "vmTrace" => nil
                       }
                     }
                   ]}
              end
            end)

          variant ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end
      end

      {:ok, sequence} = Sequence.start_link(first: 0, step: 1)

      case Keyword.fetch!(json_rpc_named_arguments, :variant) do
        EthereumJSONRPC.Geth ->
          block_number = 48230

          assert {:ok,
                  %{
                    addresses: [
                      %Explorer.Chain.Hash{
                        byte_count: 20,
                        bytes:
                          <<55, 52, 203, 24, 116, 145, 237, 231, 19, 174, 91, 59, 45, 18, 40, 74, 244, 107, 129, 1>>
                      } = first_address_hash,
                      %Explorer.Chain.Hash{
                        byte_count: 20,
                        bytes:
                          <<89, 47, 120, 202, 98, 102, 132, 20, 109, 56, 18, 133, 202, 0, 221, 145, 179, 117, 253, 17>>
                      } = second_address_hash,
                      %Explorer.Chain.Hash{
                        byte_count: 20,
                        bytes:
                          <<187, 123, 130, 135, 243, 240, 169, 51, 71, 74, 121, 234, 228, 44, 188, 169, 119, 121, 17,
                            113>>
                      } = third_address_hash,
                      %Explorer.Chain.Hash{
                        byte_count: 20,
                        bytes:
                          <<210, 193, 91, 230, 52, 135, 86, 246, 145, 187, 152, 246, 13, 254, 190, 97, 230, 190, 59,
                            86>>
                      } = fourth_address_hash,
                      %Explorer.Chain.Hash{
                        byte_count: 20,
                        bytes:
                          <<221, 47, 30, 110, 73, 130, 2, 232, 109, 143, 84, 66, 175, 89, 101, 128, 164, 240, 60, 44>>
                      } = fifth_address_hash
                    ],
                    blocks: [
                      %Explorer.Chain.Hash{
                        byte_count: 32,
                        bytes:
                          <<209, 52, 30, 145, 228, 166, 153, 192, 47, 187, 24, 4, 84, 20, 80, 18, 144, 134, 68, 198,
                            200, 119, 77, 16, 251, 182, 96, 253, 27, 146, 104, 176>>
                      }
                    ],
                    logs: [],
                    transactions: [
                      %Explorer.Chain.Hash{
                        byte_count: 32,
                        bytes:
                          <<76, 188, 236, 37, 153, 153, 224, 115, 252, 79, 176, 224, 228, 166, 18, 66, 94, 61, 115, 57,
                            47, 162, 37, 255, 36, 96, 161, 238, 171, 66, 99, 10>>
                      },
                      %Explorer.Chain.Hash{
                        byte_count: 32,
                        bytes:
                          <<240, 237, 34, 44, 16, 174, 248, 135, 4, 196, 15, 198, 34, 220, 218, 174, 13, 208, 242, 122,
                            154, 143, 4, 28, 171, 95, 190, 255, 254, 174, 75, 182>>
                      }
                    ]
                  }} = BlockFetcher.import_range(block_number..block_number, state, sequence)

          wait_for_tasks(InternalTransactionFetcher)
          wait_for_tasks(AddressBalanceFetcher)

          assert Repo.aggregate(Block, :count, :hash) == 1
          assert Repo.aggregate(Address, :count, :hash) == 5
          assert Repo.aggregate(Log, :count, :id) == 0
          assert Repo.aggregate(Transaction, :count, :hash) == 2

          first_address = Repo.get!(Address, first_address_hash)

          assert first_address.fetched_balance == %Wei{value: Decimal.new(1_999_953_415_287_753_599_000)}
          assert first_address.fetched_balance_block_number == block_number

          second_address = Repo.get!(Address, second_address_hash)

          assert second_address.fetched_balance == %Wei{value: Decimal.new(50_000_000_000_000_000)}
          assert second_address.fetched_balance_block_number == block_number

          third_address = Repo.get!(Address, third_address_hash)

          assert third_address.fetched_balance == %Wei{value: Decimal.new(30_827_986_037_499_360_709_544)}
          assert third_address.fetched_balance_block_number == block_number

          fourth_address = Repo.get!(Address, fourth_address_hash)

          assert fourth_address.fetched_balance == %Wei{value: Decimal.new(500_000_000_001_437_727_304)}
          assert fourth_address.fetched_balance_block_number == block_number

          fifth_address = Repo.get!(Address, fifth_address_hash)

          assert fifth_address.fetched_balance == %Wei{value: Decimal.new(930_417_572_224_879_702_000)}
          assert fifth_address.fetched_balance_block_number == block_number

        EthereumJSONRPC.Parity ->
          assert {:ok,
                  %{
                    addresses: [
                      %Explorer.Chain.Hash{
                        byte_count: 20,
                        bytes:
                          <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65,
                            91>>
                      } = first_address_hash,
                      %Explorer.Chain.Hash{
                        byte_count: 20,
                        bytes:
                          <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122,
                            202>>
                      } = second_address_hash
                    ],
                    blocks: [
                      %Explorer.Chain.Hash{
                        byte_count: 32,
                        bytes:
                          <<246, 180, 184, 200, 141, 243, 235, 210, 82, 236, 71, 99, 40, 51, 77, 192, 38, 207, 102, 96,
                            106, 132, 251, 118, 155, 61, 60, 188, 204, 132, 113, 189>>
                      }
                    ],
                    logs: [
                      %{
                        index: 0,
                        transaction_hash: %Explorer.Chain.Hash{
                          byte_count: 32,
                          bytes:
                            <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77,
                              57, 101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                        }
                      }
                    ],
                    transactions: [
                      %Explorer.Chain.Hash{
                        byte_count: 32,
                        bytes:
                          <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77,
                            57, 101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                      }
                    ]
                  }} = BlockFetcher.import_range(block_number..block_number, state, sequence)

          wait_for_tasks(InternalTransactionFetcher)
          wait_for_tasks(AddressBalanceFetcher)

          assert Repo.aggregate(Block, :count, :hash) == 1
          assert Repo.aggregate(Address, :count, :hash) == 2
          assert Repo.aggregate(Log, :count, :id) == 1
          assert Repo.aggregate(Transaction, :count, :hash) == 1

          first_address = Repo.get!(Address, first_address_hash)

          assert first_address.fetched_balance == %Wei{value: Decimal.new(1)}
          assert first_address.fetched_balance_block_number == block_number

          second_address = Repo.get!(Address, second_address_hash)

          assert second_address.fetched_balance == %Wei{value: Decimal.new(252_460_837_000_000_000_000_000_000)}
          assert second_address.fetched_balance_block_number == block_number

        variant ->
          raise ArgumentError, "Unsupport variant (#{variant})"
      end
    end
  end

  defp capture_log_at_level(level, block) do
    logger_level_transaction(fn ->
      Logger.configure(level: level)

      capture_log(fn ->
        block.()
        Process.sleep(10)
      end)
    end)
  end

  defp logger_level_transaction(block) do
    level_before = Logger.level()

    on_exit(fn ->
      Logger.configure(level: level_before)
    end)

    return = block.()

    Logger.configure(level: level_before)

    return
  end

  defp state(%{json_rpc_named_arguments: json_rpc_named_arguments}) do
    {:ok, state} = BlockFetcher.init(json_rpc_named_arguments: json_rpc_named_arguments)

    %{state: state}
  end

  defp wait_until(timeout, producer) do
    parent = self()
    ref = make_ref()

    spawn(fn -> do_wait_until(parent, ref, producer) end)

    receive do
      {^ref, :ok} -> :ok
    after
      timeout -> exit(:timeout)
    end
  end

  defp do_wait_until(parent, ref, producer) do
    if producer.() do
      send(parent, {ref, :ok})
    else
      :timer.sleep(100)
      do_wait_until(parent, ref, producer)
    end
  end

  defp wait_for_tasks(buffered_task) do
    wait_until(10_000, fn ->
      counts = BufferedTask.debug_count(buffered_task)
      counts.buffer == 0 and counts.tasks == 0
    end)
  end
end
