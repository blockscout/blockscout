defmodule Indexer.Block.Catchup.MassiveBlocksFetcherTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  import Mox

  alias Indexer.Block.Catchup.MassiveBlocksFetcher
  alias Indexer.Fetcher.CoinBalance.Catchup, as: CoinBalanceCatchup
  alias Indexer.Fetcher.TokenBalance.Historical, as: TokenBalanceHistorical
  alias Indexer.Fetcher.OnDemand.ContractCreator, as: ContractCreatorOnDemand

  alias Indexer.Fetcher.{
    ContractCode,
    InternalTransaction,
    ReplacedTransaction,
    Token,
    UncleBlock
  }

  alias Explorer.Chain.Block
  alias Explorer.Utility.{MassiveBlock, MissingBlockRange}

  setup :set_mox_global

  setup :verify_on_exit!

  test "successfully imports block", %{json_rpc_named_arguments: json_rpc_named_arguments} do
    %{number: block_number} = insert(:massive_block)
    block_quantity = integer_to_quantity(block_number)

    if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
      case Keyword.fetch!(json_rpc_named_arguments, :variant) do
        EthereumJSONRPC.Nethermind ->
          EthereumJSONRPC.Mox
          |> stub(:json_rpc, fn
            [%{id: id, method: "eth_getBlockByNumber", params: ["latest", false]}], _options ->
              {:ok,
               [
                 %{
                   id: id,
                   result: %{
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
                   }
                 }
               ]}

            %{method: "eth_getBlockByNumber", params: ["latest", false]}, _options ->
              {:ok,
               [
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
                 }
               ]}

            [%{id: id, method: "eth_getBlockByNumber", params: [^block_quantity, true]}], _options ->
              {:ok,
               [
                 %{
                   id: id,
                   jsonrpc: "2.0",
                   result: %{
                     "author" => "0xe2ac1c6843a33f81ae4935e5ef1277a392990381",
                     "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                     "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
                     "gasLimit" => "0x7a1200",
                     "gasUsed" => "0x0",
                     "hash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
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
                   }
                 }
               ]}
          end)

        EthereumJSONRPC.Geth ->
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

            [%{id: id, method: "eth_getBlockByNumber", params: [^block_quantity, true]}], _options ->
              {:ok,
               [
                 %{
                   id: id,
                   jsonrpc: "2.0",
                   result: %{
                     "difficulty" => "0xc22479024e55f",
                     "extraData" => "0x73656f3130",
                     "gasLimit" => "0x7a121d",
                     "gasUsed" => "0x7a0527",
                     "hash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                     "logsBloom" =>
                       "0x006a044c050a6759208088200009808898246808402123144ac15801c09a2672990130000042500000cc6090b063f195352095a88018194112101a02640000a0109c03c40568440b853a800a60044408604bb49d1d604c802008000884520208496608a520992e0f4b41a94188088920c1995107db4696c03839a911500084001009884100605084c4542953b08101103080254c34c802a00042a62f811340400d22080d000c0e39927ca481800c8024048425462000150850500205a224810041904023a80c00dc01040203000086020111210403081096822008c12500a2060a54834800400851210122c481a04a24b5284e9900a08110c180011001c03100",
                     "miner" => "0xb2930b35844a230f00e51431acae96fe543a0347",
                     "mixHash" => "0x5e07a58028d2cee7ddbefe245e6d7b5232d997b66cc906b18ad9ad51535ced24",
                     "nonce" => "0x3d88ebe8031aadf6",
                     "number" => block_quantity,
                     "parentHash" => "0x006edcaa1e6fde822908783bc4ef1ad3675532d542fce53537557391cfe34c3c",
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
               ]}
          end)

        variant_name ->
          raise ArgumentError, "Unsupported variant name (#{variant_name})"
      end
    end

    start_supervised!({Task.Supervisor, name: Indexer.Block.Catchup.TaskSupervisor})
    ContractCreatorOnDemand.start_link([[], []])
    CoinBalanceCatchup.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
    InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
    ContractCode.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
    Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
    TokenBalanceHistorical.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
    ReplacedTransaction.Supervisor.Case.start_supervised!()

    MassiveBlocksFetcher.start_link(%{task_supervisor: Indexer.Block.Catchup.TaskSupervisor})

    Process.sleep(1000)

    assert [%{number: ^block_number}] = Repo.all(Block)
    assert [] = Repo.all(MassiveBlock)
    assert [] = Repo.all(MissingBlockRange)
  end
end
