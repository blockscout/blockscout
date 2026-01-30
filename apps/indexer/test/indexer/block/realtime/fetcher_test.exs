defmodule Indexer.Block.Realtime.FetcherTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  use Utils.RuntimeEnvHelper,
    chain_identity: [:explorer, :chain_identity]

  import Mox

  alias Explorer.{Chain, Factory}
  alias Explorer.Chain.{Address, Transaction, Wei}
  alias Indexer.Block.Realtime
  alias Indexer.Fetcher.CoinBalance.Realtime, as: CoinBalanceRealtime

  alias Indexer.Fetcher.{
    ContractCode,
    InternalTransaction,
    ReplacedTransaction,
    Token,
    UncleBlock
  }

  alias Indexer.Fetcher.OnDemand.ContractCreator, as: ContractCreatorOnDemand
  alias Indexer.Fetcher.TokenBalance.Historical, as: TokenBalanceHistorical

  @moduletag capture_log: true

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
    core_json_rpc_named_arguments =
      json_rpc_named_arguments
      |> put_in([:transport_options, :url], "http://54.144.107.14:8545")
      |> put_in(
        [:transport_options, :method_to_url],
        eth_getBalance: "http://54.144.107.14:8545",
        trace_replayBlockTransactions: "http://54.144.107.14:8545",
        trace_block: "http://54.144.107.14:8545"
      )

    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    block_fetcher = %Indexer.Block.Fetcher{
      broadcast: false,
      callback_module: Realtime.Fetcher,
      json_rpc_named_arguments: core_json_rpc_named_arguments,
      task_supervisor: Indexer.TaskSupervisor
    }

    TokenBalanceHistorical.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
    CoinBalanceRealtime.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
    {:ok, _pid} = ContractCreatorOnDemand.start_link([[], []])

    Application.put_env(:indexer, Indexer.Fetcher.Celo.EpochBlockOperations.Supervisor, disabled?: true)

    Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts,
      contracts: %{
        "addresses" => %{
          "Accounts" => [],
          "Election" => [],
          "EpochRewards" => [],
          "FeeHandler" => [],
          "GasPriceMinimum" => [],
          "GoldToken" => [],
          "Governance" => [],
          "LockedGold" => [],
          "Reserve" => [],
          "StableToken" => [],
          "Validators" => []
        }
      }
    )

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts, contracts: %{})
    end)

    %{block_fetcher: block_fetcher, json_rpc_named_arguments: core_json_rpc_named_arguments}
  end

  describe "Indexer.Block.Fetcher.fetch_and_import_range/1" do
    @tag :no_geth
    test "in range with internal transactions", %{
      block_fetcher: %Indexer.Block.Fetcher{} = block_fetcher,
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      ContractCode.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      UncleBlock.Supervisor.Case.start_supervised!(block_fetcher: block_fetcher)

      ReplacedTransaction.Supervisor.Case.start_supervised!()

      Indexer.Fetcher.Filecoin.AddressInfo.Supervisor.Case.start_supervised!(
        json_rpc_named_arguments: json_rpc_named_arguments
      )

      # In CELO network, there is a token duality feature where CELO can be used
      # as both a native chain currency and as an ERC-20 token (GoldToken).
      # Transactions that transfer CELO are also counted as token transfers, and
      # the TokenInstance fetcher is called. However, for simplicity, we disable
      # it in this test.
      Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Realtime.Supervisor, disabled?: true)

      on_exit(fn ->
        Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Realtime.Supervisor, disabled?: false)
      end)

      celo_token_address_hash = Factory.address_hash()

      Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts,
        contracts: %{
          "addresses" => %{
            "GoldToken" => [
              %{
                "address" => to_string(celo_token_address_hash),
                "updated_at_block_number" => 3_946_079
              }
            ]
          }
        }
      )

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts, contracts: %{})
      end)

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_getBlockByNumber",
                                    params: ["0x3C365F", true]
                                  },
                                  %{
                                    id: 1,
                                    jsonrpc: "2.0",
                                    method: "eth_getBlockByNumber",
                                    params: ["0x3C3660", true]
                                  }
                                ],
                                _ ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "author" => "0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2",
                 "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                 "extraData" => "0xd583010b088650617269747986312e32372e32826c69",
                 "gasLimit" => "0x7a1200",
                 "gasUsed" => "0x2886e",
                 "hash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "miner" => "0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2",
                 "number" => "0x3c365f",
                 "parentHash" => "0x57f6d66e07488defccd5216c4d2968dd6afd3bd32415e284de3b02af6535e8dc",
                 "receiptsRoot" => "0x111be72e682cea9c93e02f1ef503fb64aa821b2ef510fd9177c49b37d0af98b5",
                 "sealFields" => [
                   "0x841246c63f",
                   "0xb841ba3d11db672fd7893d1b7906275fa7c4c7f4fbcc8fa29eab0331480332361516545ef10a36d800ad2be2b449dde8d5703125156a9cf8a035f5a8623463e051b700"
                 ],
                 "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                 "signature" =>
                   "ba3d11db672fd7893d1b7906275fa7c4c7f4fbcc8fa29eab0331480332361516545ef10a36d800ad2be2b449dde8d5703125156a9cf8a035f5a8623463e051b700",
                 "size" => "0x33e",
                 "stateRoot" => "0x7f73f5fb9f891213b671356126c31e9795d038844392c7aa8800ed4f52307209",
                 "step" => "306628159",
                 "timestamp" => "0x5b61df3b",
                 "totalDifficulty" => "0x3c365effffffffffffffffffffffffed7f0362",
                 "transactions" => [
                   %{
                     "blockHash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                     "blockNumber" => "0x3c365f",
                     "chainId" => "0x63",
                     "condition" => nil,
                     "creates" => nil,
                     "from" => "0x40b18103537c0f15d5e137dd8ddd019b84949d16",
                     "gas" => "0x3d9c5",
                     "gasPrice" => "0x3b9aca00",
                     "hash" => "0xd3937e70fab3fb2bfe8feefac36815408bf07de3b9e09fe81114b9a6b17f55c8",
                     "input" =>
                       "0x8841ac11000000000000000000000000000000000000000000000000000000000000006c000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005",
                     "nonce" => "0x65b",
                     "publicKey" =>
                       "0x89c2123ed4b5d141cf1f4b6f5f3d754418f03aea2e870a1c50888d94bf5531f74237e2fea72d0bc198ef213272b62c6869615720757255e6cba087f9db6e759f",
                     "r" => "0x55a1a93541d7f782f97f6699437bb60fa4606d63760b30c1ee317e648f93995",
                     "raw" =>
                       "0xf8f582065b843b9aca008303d9c594698bf6943bab687b2756394624aa183f434f65da8901158e4f216242a000b8848841ac11000000000000000000000000000000000000000000000000000000000000006c00000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000581eaa0055a1a93541d7f782f97f6699437bb60fa4606d63760b30c1ee317e648f93995a06affd4da5eca84fbca2b016c980f861e0af1f8d6535e2fe29d8f96dc0ce358f7",
                     "s" => "0x6affd4da5eca84fbca2b016c980f861e0af1f8d6535e2fe29d8f96dc0ce358f7",
                     "standardV" => "0x1",
                     "to" => "0x698bf6943bab687b2756394624aa183f434f65da",
                     "transactionIndex" => "0x0",
                     "v" => "0xea",
                     "value" => "0x1158e4f216242a000"
                   }
                 ],
                 "transactionsRoot" => "0xd7c39a93eafe0bdcbd1324c13dcd674bed8c9fa8adbf8f95bf6a59788985da6f",
                 "uncles" => ["0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cd"]
               }
             },
             %{
               id: 1,
               jsonrpc: "2.0",
               result: %{
                 "author" => "0x66c9343c7e8ca673a1fedf9dbf2cd7936dbbf7e3",
                 "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                 "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
                 "gasLimit" => "0x7a1200",
                 "gasUsed" => "0x0",
                 "hash" => "0xfb483e511d316fa4072694da3f7abc94b06286406af45061e5e681395bdc6815",
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "miner" => "0x66c9343c7e8ca673a1fedf9dbf2cd7936dbbf7e3",
                 "number" => "0x3c3660",
                 "parentHash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                 "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                 "sealFields" => [
                   "0x841246c640",
                   "0xb84114db3fd7526b7ea3635f5c85c30dd8a645453aa2f8afe5fd33fe0ec663c9c7b653b0fb5d8dc7d0b809674fa9dca9887d1636a586bf62191da22255eb068bf20800"
                 ],
                 "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                 "signature" =>
                   "14db3fd7526b7ea3635f5c85c30dd8a645453aa2f8afe5fd33fe0ec663c9c7b653b0fb5d8dc7d0b809674fa9dca9887d1636a586bf62191da22255eb068bf20800",
                 "size" => "0x243",
                 "stateRoot" => "0x3174c461989e9f99e08fa9b4ffb8bce8d9a281c8fc9f80694bb9d3acd4f15559",
                 "step" => "306628160",
                 "timestamp" => "0x5b61df40",
                 "totalDifficulty" => "0x3c365fffffffffffffffffffffffffed7f0360",
                 "transactions" => [],
                 "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                 "uncles" => []
               }
             }
           ]}
        end)
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_getTransactionReceipt",
                                    params: ["0xd3937e70fab3fb2bfe8feefac36815408bf07de3b9e09fe81114b9a6b17f55c8"]
                                  }
                                ],
                                _ ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "blockHash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                 "blockNumber" => "0x3c365f",
                 "contractAddress" => nil,
                 "cumulativeGasUsed" => "0x2886e",
                 "gasUsed" => "0x2886e",
                 "logs" => [],
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "root" => nil,
                 "status" => "0x1",
                 "transactionHash" => "0xd3937e70fab3fb2bfe8feefac36815408bf07de3b9e09fe81114b9a6b17f55c8",
                 "transactionIndex" => "0x0"
               }
             }
           ]}
        end)
        |> expect(:json_rpc, 1, fn
          [
            %{id: 0, jsonrpc: "2.0", method: "trace_block", params: ["0x3C365F"]},
            %{id: 1, jsonrpc: "2.0", method: "trace_block", params: ["0x3C3660"]}
          ],
          _ ->
            {:ok,
             [
               %{id: 0, jsonrpc: "2.0", result: []},
               %{id: 1, jsonrpc: "2.0", result: []}
             ]}

          [
            %{
              id: 0,
              jsonrpc: "2.0",
              method: "eth_getBlockByNumber",
              params: ["0x3C365F", true]
            }
          ],
          _ ->
            {:ok,
             [
               %{
                 id: 0,
                 jsonrpc: "2.0",
                 result: %{
                   "author" => "0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2",
                   "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                   "extraData" => "0xd583010b088650617269747986312e32372e32826c69",
                   "gasLimit" => "0x7a1200",
                   "gasUsed" => "0x2886e",
                   "hash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                   "logsBloom" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                   "miner" => "0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2",
                   "number" => "0x3c365f",
                   "parentHash" => "0x57f6d66e07488defccd5216c4d2968dd6afd3bd32415e284de3b02af6535e8dc",
                   "receiptsRoot" => "0x111be72e682cea9c93e02f1ef503fb64aa821b2ef510fd9177c49b37d0af98b5",
                   "sealFields" => [
                     "0x841246c63f",
                     "0xb841ba3d11db672fd7893d1b7906275fa7c4c7f4fbcc8fa29eab0331480332361516545ef10a36d800ad2be2b449dde8d5703125156a9cf8a035f5a8623463e051b700"
                   ],
                   "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                   "signature" =>
                     "ba3d11db672fd7893d1b7906275fa7c4c7f4fbcc8fa29eab0331480332361516545ef10a36d800ad2be2b449dde8d5703125156a9cf8a035f5a8623463e051b700",
                   "size" => "0x33e",
                   "stateRoot" => "0x7f73f5fb9f891213b671356126c31e9795d038844392c7aa8800ed4f52307209",
                   "step" => "306628159",
                   "timestamp" => "0x5b61df3b",
                   "totalDifficulty" => "0x3c365effffffffffffffffffffffffed7f0362",
                   "transactions" => [
                     %{
                       "blockHash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                       "blockNumber" => "0x3c365f",
                       "chainId" => "0x63",
                       "condition" => nil,
                       "creates" => nil,
                       "from" => "0x40b18103537c0f15d5e137dd8ddd019b84949d16",
                       "gas" => "0x3d9c5",
                       "gasPrice" => "0x3b9aca00",
                       "hash" => "0xd3937e70fab3fb2bfe8feefac36815408bf07de3b9e09fe81114b9a6b17f55c8",
                       "input" =>
                         "0x8841ac11000000000000000000000000000000000000000000000000000000000000006c000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005",
                       "nonce" => "0x65b",
                       "publicKey" =>
                         "0x89c2123ed4b5d141cf1f4b6f5f3d754418f03aea2e870a1c50888d94bf5531f74237e2fea72d0bc198ef213272b62c6869615720757255e6cba087f9db6e759f",
                       "r" => "0x55a1a93541d7f782f97f6699437bb60fa4606d63760b30c1ee317e648f93995",
                       "raw" =>
                         "0xf8f582065b843b9aca008303d9c594698bf6943bab687b2756394624aa183f434f65da8901158e4f216242a000b8848841ac11000000000000000000000000000000000000000000000000000000000000006c00000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000581eaa0055a1a93541d7f782f97f6699437bb60fa4606d63760b30c1ee317e648f93995a06affd4da5eca84fbca2b016c980f861e0af1f8d6535e2fe29d8f96dc0ce358f7",
                       "s" => "0x6affd4da5eca84fbca2b016c980f861e0af1f8d6535e2fe29d8f96dc0ce358f7",
                       "standardV" => "0x1",
                       "to" => "0x698bf6943bab687b2756394624aa183f434f65da",
                       "transactionIndex" => "0x0",
                       "v" => "0xea",
                       "value" => "0x1158e4f216242a000"
                     }
                   ],
                   "transactionsRoot" => "0xd7c39a93eafe0bdcbd1324c13dcd674bed8c9fa8adbf8f95bf6a59788985da6f",
                   "uncles" => ["0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cd"]
                 }
               }
             ]}

          [
            %{
              id: 0,
              jsonrpc: "2.0",
              method: "eth_getBlockByNumber",
              params: ["0x3C3660", true]
            }
          ],
          _ ->
            {:ok,
             [
               %{
                 id: 0,
                 jsonrpc: "2.0",
                 result: %{
                   "author" => "0x66c9343c7e8ca673a1fedf9dbf2cd7936dbbf7e3",
                   "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                   "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
                   "gasLimit" => "0x7a1200",
                   "gasUsed" => "0x0",
                   "hash" => "0xfb483e511d316fa4072694da3f7abc94b06286406af45061e5e681395bdc6815",
                   "logsBloom" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                   "miner" => "0x66c9343c7e8ca673a1fedf9dbf2cd7936dbbf7e3",
                   "number" => "0x3c3660",
                   "parentHash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                   "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "sealFields" => [
                     "0x841246c640",
                     "0xb84114db3fd7526b7ea3635f5c85c30dd8a645453aa2f8afe5fd33fe0ec663c9c7b653b0fb5d8dc7d0b809674fa9dca9887d1636a586bf62191da22255eb068bf20800"
                   ],
                   "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                   "signature" =>
                     "14db3fd7526b7ea3635f5c85c30dd8a645453aa2f8afe5fd33fe0ec663c9c7b653b0fb5d8dc7d0b809674fa9dca9887d1636a586bf62191da22255eb068bf20800",
                   "size" => "0x243",
                   "stateRoot" => "0x3174c461989e9f99e08fa9b4ffb8bce8d9a281c8fc9f80694bb9d3acd4f15559",
                   "step" => "306628160",
                   "timestamp" => "0x5b61df40",
                   "totalDifficulty" => "0x3c365fffffffffffffffffffffffffed7f0360",
                   "transactions" => [],
                   "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "uncles" => []
                 }
               }
             ]}

          [
            %{
              id: 0,
              jsonrpc: "2.0",
              method: "trace_replayBlockTransactions",
              params: [
                "0x3C3660",
                ["trace"]
              ]
            },
            %{
              id: 1,
              jsonrpc: "2.0",
              method: "trace_replayBlockTransactions",
              params: [
                "0x3C365F",
                ["trace"]
              ]
            }
          ],
          _ ->
            {:ok,
             [
               %{id: 0, jsonrpc: "2.0", result: []},
               %{
                 id: 1,
                 jsonrpc: "2.0",
                 result: [
                   %{
                     "output" => "0x",
                     "stateDiff" => nil,
                     "trace" => [
                       %{
                         "action" => %{
                           "callType" => "call",
                           "from" => "0x40b18103537c0f15d5e137dd8ddd019b84949d16",
                           "gas" => "0x383ad",
                           "input" =>
                             "0x8841ac11000000000000000000000000000000000000000000000000000000000000006c000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005",
                           "to" => "0x698bf6943bab687b2756394624aa183f434f65da",
                           "value" => "0x1158e4f216242a000"
                         },
                         "result" => %{"gasUsed" => "0x23256", "output" => "0x"},
                         "subtraces" => 5,
                         "traceAddress" => [],
                         "type" => "call"
                       },
                       %{
                         "action" => %{
                           "callType" => "call",
                           "from" => "0x698bf6943bab687b2756394624aa183f434f65da",
                           "gas" => "0x36771",
                           "input" => "0x6352211e000000000000000000000000000000000000000000000000000000000000006c",
                           "to" => "0x11c4469d974f8af5ba9ec99f3c42c07c848c861c",
                           "value" => "0x0"
                         },
                         "result" => %{
                           "gasUsed" => "0x495",
                           "output" => "0x00000000000000000000000040b18103537c0f15d5e137dd8ddd019b84949d16"
                         },
                         "subtraces" => 0,
                         "traceAddress" => [0],
                         "type" => "call"
                       },
                       %{
                         "action" => %{
                           "callType" => "call",
                           "from" => "0x698bf6943bab687b2756394624aa183f434f65da",
                           "gas" => "0x35acb",
                           "input" => "0x33f30a43000000000000000000000000000000000000000000000000000000000000006c",
                           "to" => "0x11c4469d974f8af5ba9ec99f3c42c07c848c861c",
                           "value" => "0x0"
                         },
                         "result" => %{
                           "gasUsed" => "0x52d2",
                           "output" =>
                             "0x00000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000058000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000004e000000000000000000000000000000000000000000000000000000000000004f000000000000000000000000000000000000000000000000000000000000004d000000000000000000000000000000000000000000000000000000000000004b000000000000000000000000000000000000000000000000000000000000004f00000000000000000000000000000000000000000000000000000000000000b000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000044000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000078000000000000000000000000000000000000000000000000000000005b61df09000000000000000000000000000000000000000000000000000000005b61df5e000000000000000000000000000000000000000000000000000000005b61df8b000000000000000000000000000000000000000000000000000000005b61df2c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006c00000000000000000000000000000000000000000000000000000000000000fd000000000000000000000000000000000000000000000000000000000000004e000000000000000000000000000000000000000000000000000000000000007a000000000000000000000000000000000000000000000000000000000000004e0000000000000000000000000000000000000000000000000000000000000015000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000189000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000054c65696c61000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002566303430313037303331343330303332333036303933333235303131323036303730373131000000000000000000000000000000000000000000000000000000"
                         },
                         "subtraces" => 0,
                         "traceAddress" => [1],
                         "type" => "call"
                       },
                       %{
                         "action" => %{
                           "callType" => "call",
                           "from" => "0x698bf6943bab687b2756394624aa183f434f65da",
                           "gas" => "0x2fc79",
                           "input" => "0x1b8ef0bb000000000000000000000000000000000000000000000000000000000000006c",
                           "to" => "0x11c4469d974f8af5ba9ec99f3c42c07c848c861c",
                           "value" => "0x0"
                         },
                         "result" => %{
                           "gasUsed" => "0x10f2",
                           "output" => "0x0000000000000000000000000000000000000000000000000000000000000013"
                         },
                         "subtraces" => 0,
                         "traceAddress" => [2],
                         "type" => "call"
                       },
                       %{
                         "action" => %{
                           "callType" => "call",
                           "from" => "0x698bf6943bab687b2756394624aa183f434f65da",
                           "gas" => "0x2e21f",
                           "input" =>
                             "0xcf5f87d0000000000000000000000000000000000000000000000000000000000000006c0000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000a",
                           "to" => "0x11c4469d974f8af5ba9ec99f3c42c07c848c861c",
                           "value" => "0x0"
                         },
                         "result" => %{"gasUsed" => "0x1ca1", "output" => "0x"},
                         "subtraces" => 0,
                         "traceAddress" => [3],
                         "type" => "call"
                       },
                       %{
                         "action" => %{
                           "callType" => "call",
                           "from" => "0x698bf6943bab687b2756394624aa183f434f65da",
                           "gas" => "0x8fc",
                           "input" => "0x",
                           "to" => "0x40b18103537c0f15d5e137dd8ddd019b84949d16",
                           "value" => "0x9184e72a000"
                         },
                         "result" => %{"gasUsed" => "0x0", "output" => "0x"},
                         "subtraces" => 0,
                         "traceAddress" => [4],
                         "type" => "call"
                       }
                     ],
                     "transactionHash" => "0xd3937e70fab3fb2bfe8feefac36815408bf07de3b9e09fe81114b9a6b17f55c8",
                     "vmTrace" => nil
                   }
                 ]
               }
             ]}
        end)
      end

      assert {:ok,
              %{
                inserted: %{
                  addresses: addresses,
                  address_coin_balances: [
                    %{
                      address_hash: first_address_hash,
                      block_number: 3_946_079
                    },
                    %{
                      address_hash: second_address_hash,
                      block_number: 3_946_079
                    },
                    %{
                      address_hash: third_address_hash,
                      block_number: 3_946_080
                    },
                    %{
                      address_hash: fourth_address_hash,
                      block_number: 3_946_079
                    }
                  ],
                  blocks: [%Chain.Block{number: 3_946_079}, %Chain.Block{number: 3_946_080}],
                  transactions: [%Transaction{hash: _transaction_hash}]
                },
                errors: []
              }} = Indexer.Block.Fetcher.fetch_and_import_range(block_fetcher, 3_946_079..3_946_080)

      if chain_identity() != {:optimism, :celo} do
        assert [
                 %Address{hash: ^first_address_hash},
                 %Address{hash: ^second_address_hash},
                 %Address{hash: ^third_address_hash},
                 %Address{hash: ^fourth_address_hash}
               ] = addresses
      else
        assert [
                 %Address{hash: ^celo_token_address_hash},
                 %Address{hash: ^first_address_hash},
                 %Address{hash: ^second_address_hash},
                 %Address{hash: ^third_address_hash},
                 %Address{hash: ^fourth_address_hash}
               ] = addresses
      end
    end

    @tag :no_geth
    test "in range with internal transactions and manual reward fetching", %{
      block_fetcher: %Indexer.Block.Fetcher{} = block_fetcher,
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      Application.put_env(:indexer, :fetch_rewards_way, "manual")

      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      ContractCode.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      UncleBlock.Supervisor.Case.start_supervised!(block_fetcher: block_fetcher)

      Indexer.Fetcher.Filecoin.AddressInfo.Supervisor.Case.start_supervised!(
        json_rpc_named_arguments: json_rpc_named_arguments
      )

      ReplacedTransaction.Supervisor.Case.start_supervised!()

      # In CELO network, there is a token duality feature where CELO can be used
      # as both a native chain currency and as an ERC-20 token (GoldToken).
      # Transactions that transfer CELO are also counted as token transfers, and
      # the TokenInstance fetcher is called. However, for simplicity, we disable
      # it in this test.
      Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Realtime.Supervisor, disabled?: true)

      on_exit(fn ->
        Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Realtime.Supervisor, disabled?: false)
      end)

      celo_token_address_hash = Factory.address_hash()

      Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts,
        contracts: %{
          "addresses" => %{
            "GoldToken" => [
              %{
                "address" => to_string(celo_token_address_hash),
                "updated_at_block_number" => 3_946_079
              }
            ]
          }
        }
      )

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts, contracts: %{})
      end)

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_getBlockByNumber",
                                    params: ["0x3C365F", true]
                                  },
                                  %{
                                    id: 1,
                                    jsonrpc: "2.0",
                                    method: "eth_getBlockByNumber",
                                    params: ["0x3C3660", true]
                                  }
                                ],
                                _ ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "author" => "0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2",
                 "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                 "extraData" => "0xd583010b088650617269747986312e32372e32826c69",
                 "gasLimit" => "0x7a1200",
                 "gasUsed" => "0x2886e",
                 "hash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "miner" => "0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2",
                 "number" => "0x3c365f",
                 "parentHash" => "0x57f6d66e07488defccd5216c4d2968dd6afd3bd32415e284de3b02af6535e8dc",
                 "receiptsRoot" => "0x111be72e682cea9c93e02f1ef503fb64aa821b2ef510fd9177c49b37d0af98b5",
                 "sealFields" => [
                   "0x841246c63f",
                   "0xb841ba3d11db672fd7893d1b7906275fa7c4c7f4fbcc8fa29eab0331480332361516545ef10a36d800ad2be2b449dde8d5703125156a9cf8a035f5a8623463e051b700"
                 ],
                 "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                 "signature" =>
                   "ba3d11db672fd7893d1b7906275fa7c4c7f4fbcc8fa29eab0331480332361516545ef10a36d800ad2be2b449dde8d5703125156a9cf8a035f5a8623463e051b700",
                 "size" => "0x33e",
                 "stateRoot" => "0x7f73f5fb9f891213b671356126c31e9795d038844392c7aa8800ed4f52307209",
                 "step" => "306628159",
                 "timestamp" => "0x5b61df3b",
                 "totalDifficulty" => "0x3c365effffffffffffffffffffffffed7f0362",
                 "transactions" => [
                   %{
                     "blockHash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                     "blockNumber" => "0x3c365f",
                     "chainId" => "0x63",
                     "condition" => nil,
                     "creates" => nil,
                     "from" => "0x40b18103537c0f15d5e137dd8ddd019b84949d16",
                     "gas" => "0x3d9c5",
                     "gasPrice" => "0x3b9aca00",
                     "hash" => "0xd3937e70fab3fb2bfe8feefac36815408bf07de3b9e09fe81114b9a6b17f55c8",
                     "input" =>
                       "0x8841ac11000000000000000000000000000000000000000000000000000000000000006c000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005",
                     "nonce" => "0x65b",
                     "publicKey" =>
                       "0x89c2123ed4b5d141cf1f4b6f5f3d754418f03aea2e870a1c50888d94bf5531f74237e2fea72d0bc198ef213272b62c6869615720757255e6cba087f9db6e759f",
                     "r" => "0x55a1a93541d7f782f97f6699437bb60fa4606d63760b30c1ee317e648f93995",
                     "raw" =>
                       "0xf8f582065b843b9aca008303d9c594698bf6943bab687b2756394624aa183f434f65da8901158e4f216242a000b8848841ac11000000000000000000000000000000000000000000000000000000000000006c00000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000581eaa0055a1a93541d7f782f97f6699437bb60fa4606d63760b30c1ee317e648f93995a06affd4da5eca84fbca2b016c980f861e0af1f8d6535e2fe29d8f96dc0ce358f7",
                     "s" => "0x6affd4da5eca84fbca2b016c980f861e0af1f8d6535e2fe29d8f96dc0ce358f7",
                     "standardV" => "0x1",
                     "to" => "0x698bf6943bab687b2756394624aa183f434f65da",
                     "transactionIndex" => "0x0",
                     "v" => "0xea",
                     "value" => "0x1158e4f216242a000"
                   }
                 ],
                 "transactionsRoot" => "0xd7c39a93eafe0bdcbd1324c13dcd674bed8c9fa8adbf8f95bf6a59788985da6f",
                 "uncles" => ["0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cd"]
               }
             },
             %{
               id: 1,
               jsonrpc: "2.0",
               result: %{
                 "author" => "0x66c9343c7e8ca673a1fedf9dbf2cd7936dbbf7e3",
                 "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                 "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
                 "gasLimit" => "0x7a1200",
                 "gasUsed" => "0x0",
                 "hash" => "0xfb483e511d316fa4072694da3f7abc94b06286406af45061e5e681395bdc6815",
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "miner" => "0x66c9343c7e8ca673a1fedf9dbf2cd7936dbbf7e3",
                 "number" => "0x3c3660",
                 "parentHash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                 "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                 "sealFields" => [
                   "0x841246c640",
                   "0xb84114db3fd7526b7ea3635f5c85c30dd8a645453aa2f8afe5fd33fe0ec663c9c7b653b0fb5d8dc7d0b809674fa9dca9887d1636a586bf62191da22255eb068bf20800"
                 ],
                 "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                 "signature" =>
                   "14db3fd7526b7ea3635f5c85c30dd8a645453aa2f8afe5fd33fe0ec663c9c7b653b0fb5d8dc7d0b809674fa9dca9887d1636a586bf62191da22255eb068bf20800",
                 "size" => "0x243",
                 "stateRoot" => "0x3174c461989e9f99e08fa9b4ffb8bce8d9a281c8fc9f80694bb9d3acd4f15559",
                 "step" => "306628160",
                 "timestamp" => "0x5b61df40",
                 "totalDifficulty" => "0x3c365fffffffffffffffffffffffffed7f0360",
                 "transactions" => [],
                 "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                 "uncles" => []
               }
             }
           ]}
        end)
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_getTransactionReceipt",
                                    params: ["0xd3937e70fab3fb2bfe8feefac36815408bf07de3b9e09fe81114b9a6b17f55c8"]
                                  }
                                ],
                                _ ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "blockHash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                 "blockNumber" => "0x3c365f",
                 "contractAddress" => nil,
                 "cumulativeGasUsed" => "0x2886e",
                 "gasUsed" => "0x2886e",
                 "logs" => [],
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "root" => nil,
                 "status" => "0x1",
                 "transactionHash" => "0xd3937e70fab3fb2bfe8feefac36815408bf07de3b9e09fe81114b9a6b17f55c8",
                 "transactionIndex" => "0x0"
               }
             }
           ]}
        end)
      end

      first_expected_reward = %Wei{value: Decimal.new(165_998_000_000_000)}
      second_expected_reward = %Wei{value: Decimal.new(0)}

      assert {:ok,
              %{
                inserted: %{
                  addresses: addresses,
                  address_coin_balances: [
                    %{
                      address_hash: first_address_hash,
                      block_number: 3_946_079
                    },
                    %{
                      address_hash: second_address_hash,
                      block_number: 3_946_079
                    },
                    %{
                      address_hash: third_address_hash,
                      block_number: 3_946_080
                    },
                    %{
                      address_hash: fourth_address_hash,
                      block_number: 3_946_079
                    }
                  ],
                  block_rewards: [
                    %{
                      address_hash: second_address_hash,
                      address_type: :validator,
                      reward: ^first_expected_reward
                    },
                    %{
                      address_hash: third_address_hash,
                      address_type: :validator,
                      reward: ^second_expected_reward
                    }
                  ],
                  blocks: [%Chain.Block{number: 3_946_079}, %Chain.Block{number: 3_946_080}],
                  transactions: [%Transaction{hash: _transaction_hash}]
                },
                errors: []
              }} = Indexer.Block.Fetcher.fetch_and_import_range(block_fetcher, 3_946_079..3_946_080)

      if chain_identity() != {:optimism, :celo} do
        assert [
                 %Address{hash: ^first_address_hash},
                 %Address{hash: ^second_address_hash},
                 %Address{hash: ^third_address_hash},
                 %Address{hash: ^fourth_address_hash}
               ] = addresses
      else
        assert [
                 %Address{hash: ^celo_token_address_hash},
                 %Address{hash: ^first_address_hash},
                 %Address{hash: ^second_address_hash},
                 %Address{hash: ^third_address_hash},
                 %Address{hash: ^fourth_address_hash}
               ] = addresses
      end

      Application.put_env(:indexer, :fetch_rewards_way, nil)
    end

    if Application.compile_env(:explorer, :chain_type) == :stability do
      @tag :no_geth
      test "update stability validator counter", %{
        block_fetcher: %Indexer.Block.Fetcher{} = block_fetcher,
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

        ContractCode.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

        InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

        UncleBlock.Supervisor.Case.start_supervised!(block_fetcher: block_fetcher)

        ReplacedTransaction.Supervisor.Case.start_supervised!()

        Indexer.Fetcher.Filecoin.AddressInfo.Supervisor.Case.start_supervised!(
          json_rpc_named_arguments: json_rpc_named_arguments
        )

        # In CELO network, there is a token duality feature where CELO can be used
        # as both a native chain currency and as an ERC-20 token (GoldToken).
        # Transactions that transfer CELO are also counted as token transfers, and
        # the TokenInstance fetcher is called. However, for simplicity, we disable
        # it in this test.
        Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Realtime.Supervisor, disabled?: true)

        on_exit(fn ->
          Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Realtime.Supervisor, disabled?: false)
        end)

        validator_1 = insert(:validator_stability)
        validator_2 = insert(:validator_stability)

        if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
          EthereumJSONRPC.Mox
          |> expect(:json_rpc, fn [
                                    %{
                                      id: 0,
                                      jsonrpc: "2.0",
                                      method: "eth_getBlockByNumber",
                                      params: ["0x3C365F", true]
                                    },
                                    %{
                                      id: 1,
                                      jsonrpc: "2.0",
                                      method: "eth_getBlockByNumber",
                                      params: ["0x3C3660", true]
                                    }
                                  ],
                                  _ ->
            {:ok,
             [
               %{
                 id: 0,
                 jsonrpc: "2.0",
                 result: %{
                   "author" => "0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2",
                   "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                   "extraData" => "0xd583010b088650617269747986312e32372e32826c69",
                   "gasLimit" => "0x7a1200",
                   "gasUsed" => "0x2886e",
                   "hash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                   "logsBloom" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                   "miner" => to_string(validator_1.address_hash),
                   "number" => "0x3c365f",
                   "parentHash" => "0x57f6d66e07488defccd5216c4d2968dd6afd3bd32415e284de3b02af6535e8dc",
                   "receiptsRoot" => "0x111be72e682cea9c93e02f1ef503fb64aa821b2ef510fd9177c49b37d0af98b5",
                   "sealFields" => [
                     "0x841246c63f",
                     "0xb841ba3d11db672fd7893d1b7906275fa7c4c7f4fbcc8fa29eab0331480332361516545ef10a36d800ad2be2b449dde8d5703125156a9cf8a035f5a8623463e051b700"
                   ],
                   "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                   "signature" =>
                     "ba3d11db672fd7893d1b7906275fa7c4c7f4fbcc8fa29eab0331480332361516545ef10a36d800ad2be2b449dde8d5703125156a9cf8a035f5a8623463e051b700",
                   "size" => "0x33e",
                   "stateRoot" => "0x7f73f5fb9f891213b671356126c31e9795d038844392c7aa8800ed4f52307209",
                   "step" => "306628159",
                   "timestamp" => "0x5b61df3b",
                   "totalDifficulty" => "0x3c365effffffffffffffffffffffffed7f0362",
                   "transactions" => [],
                   "transactionsRoot" => "0xd7c39a93eafe0bdcbd1324c13dcd674bed8c9fa8adbf8f95bf6a59788985da6f",
                   "uncles" => ["0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cd"]
                 }
               },
               %{
                 id: 1,
                 jsonrpc: "2.0",
                 result: %{
                   "author" => "0x66c9343c7e8ca673a1fedf9dbf2cd7936dbbf7e3",
                   "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                   "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
                   "gasLimit" => "0x7a1200",
                   "gasUsed" => "0x0",
                   "hash" => "0xfb483e511d316fa4072694da3f7abc94b06286406af45061e5e681395bdc6815",
                   "logsBloom" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                   "miner" => to_string(validator_2.address_hash),
                   "number" => "0x3c3660",
                   "parentHash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                   "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "sealFields" => [
                     "0x841246c640",
                     "0xb84114db3fd7526b7ea3635f5c85c30dd8a645453aa2f8afe5fd33fe0ec663c9c7b653b0fb5d8dc7d0b809674fa9dca9887d1636a586bf62191da22255eb068bf20800"
                   ],
                   "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                   "signature" =>
                     "14db3fd7526b7ea3635f5c85c30dd8a645453aa2f8afe5fd33fe0ec663c9c7b653b0fb5d8dc7d0b809674fa9dca9887d1636a586bf62191da22255eb068bf20800",
                   "size" => "0x243",
                   "stateRoot" => "0x3174c461989e9f99e08fa9b4ffb8bce8d9a281c8fc9f80694bb9d3acd4f15559",
                   "step" => "306628160",
                   "timestamp" => "0x5b61df40",
                   "totalDifficulty" => "0x3c365fffffffffffffffffffffffffed7f0360",
                   "transactions" => [],
                   "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "uncles" => []
                 }
               }
             ]}
          end)
          |> expect(:json_rpc, 1, fn
            [
              %{id: 0, jsonrpc: "2.0", method: "trace_block", params: ["0x3C365F"]},
              %{id: 1, jsonrpc: "2.0", method: "trace_block", params: ["0x3C3660"]}
            ],
            _ ->
              {:ok,
               [
                 %{id: 0, jsonrpc: "2.0", result: []},
                 %{id: 1, jsonrpc: "2.0", result: []}
               ]}

            [
              %{
                id: 0,
                jsonrpc: "2.0",
                method: "eth_getBlockByNumber",
                params: ["0x3C365F", true]
              }
            ],
            _ ->
              {:ok,
               [
                 %{
                   id: 0,
                   jsonrpc: "2.0",
                   result: %{
                     "author" => "0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2",
                     "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                     "extraData" => "0xd583010b088650617269747986312e32372e32826c69",
                     "gasLimit" => "0x7a1200",
                     "gasUsed" => "0x2886e",
                     "hash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                     "logsBloom" =>
                       "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                     "miner" => "0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2",
                     "number" => "0x3c365f",
                     "parentHash" => "0x57f6d66e07488defccd5216c4d2968dd6afd3bd32415e284de3b02af6535e8dc",
                     "receiptsRoot" => "0x111be72e682cea9c93e02f1ef503fb64aa821b2ef510fd9177c49b37d0af98b5",
                     "sealFields" => [
                       "0x841246c63f",
                       "0xb841ba3d11db672fd7893d1b7906275fa7c4c7f4fbcc8fa29eab0331480332361516545ef10a36d800ad2be2b449dde8d5703125156a9cf8a035f5a8623463e051b700"
                     ],
                     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                     "signature" =>
                       "ba3d11db672fd7893d1b7906275fa7c4c7f4fbcc8fa29eab0331480332361516545ef10a36d800ad2be2b449dde8d5703125156a9cf8a035f5a8623463e051b700",
                     "size" => "0x33e",
                     "stateRoot" => "0x7f73f5fb9f891213b671356126c31e9795d038844392c7aa8800ed4f52307209",
                     "step" => "306628159",
                     "timestamp" => "0x5b61df3b",
                     "totalDifficulty" => "0x3c365effffffffffffffffffffffffed7f0362",
                     "transactions" => [],
                     "transactionsRoot" => "0xd7c39a93eafe0bdcbd1324c13dcd674bed8c9fa8adbf8f95bf6a59788985da6f",
                     "uncles" => ["0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cd"]
                   }
                 }
               ]}

            [
              %{
                id: 0,
                jsonrpc: "2.0",
                method: "eth_getBlockByNumber",
                params: ["0x3C3660", true]
              }
            ],
            _ ->
              {:ok,
               [
                 %{
                   id: 0,
                   jsonrpc: "2.0",
                   result: %{
                     "author" => "0x66c9343c7e8ca673a1fedf9dbf2cd7936dbbf7e3",
                     "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                     "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
                     "gasLimit" => "0x7a1200",
                     "gasUsed" => "0x0",
                     "hash" => "0xfb483e511d316fa4072694da3f7abc94b06286406af45061e5e681395bdc6815",
                     "logsBloom" =>
                       "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                     "miner" => "0x66c9343c7e8ca673a1fedf9dbf2cd7936dbbf7e3",
                     "number" => "0x3c3660",
                     "parentHash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
                     "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                     "sealFields" => [
                       "0x841246c640",
                       "0xb84114db3fd7526b7ea3635f5c85c30dd8a645453aa2f8afe5fd33fe0ec663c9c7b653b0fb5d8dc7d0b809674fa9dca9887d1636a586bf62191da22255eb068bf20800"
                     ],
                     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                     "signature" =>
                       "14db3fd7526b7ea3635f5c85c30dd8a645453aa2f8afe5fd33fe0ec663c9c7b653b0fb5d8dc7d0b809674fa9dca9887d1636a586bf62191da22255eb068bf20800",
                     "size" => "0x243",
                     "stateRoot" => "0x3174c461989e9f99e08fa9b4ffb8bce8d9a281c8fc9f80694bb9d3acd4f15559",
                     "step" => "306628160",
                     "timestamp" => "0x5b61df40",
                     "totalDifficulty" => "0x3c365fffffffffffffffffffffffffed7f0360",
                     "transactions" => [],
                     "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                     "uncles" => []
                   }
                 }
               ]}

            [
              %{
                id: 0,
                jsonrpc: "2.0",
                method: "trace_replayBlockTransactions",
                params: [
                  "0x3C3660",
                  ["trace"]
                ]
              },
              %{
                id: 1,
                jsonrpc: "2.0",
                method: "trace_replayBlockTransactions",
                params: [
                  "0x3C365F",
                  ["trace"]
                ]
              }
            ],
            _ ->
              {:ok,
               [
                 %{id: 0, jsonrpc: "2.0", result: []},
                 %{
                   id: 1,
                   jsonrpc: "2.0",
                   result: []
                 }
               ]}
          end)
        end

        validator_1_address_hash = validator_1.address_hash
        validator_2_address_hash = validator_2.address_hash

        assert {:ok,
                %{
                  inserted: %{
                    blocks: [%Chain.Block{number: 3_946_079}, %Chain.Block{number: 3_946_080}],
                    stability_validators: [
                      %Explorer.Chain.Stability.Validator{
                        address_hash: ^validator_1_address_hash,
                        blocks_validated: blocks_validated_1
                      },
                      %Explorer.Chain.Stability.Validator{
                        address_hash: ^validator_2_address_hash,
                        blocks_validated: blocks_validated_2
                      }
                    ]
                  },
                  errors: []
                }} = Indexer.Block.Fetcher.fetch_and_import_range(block_fetcher, 3_946_079..3_946_080)

        validator_from_db = Repo.get!(Explorer.Chain.Stability.Validator, validator_1.address_hash)
        assert validator_from_db.blocks_validated == blocks_validated_1
        assert validator_from_db.blocks_validated == validator_1.blocks_validated + 1

        validator_from_db = Repo.get!(Explorer.Chain.Stability.Validator, validator_2.address_hash)
        assert validator_from_db.blocks_validated == blocks_validated_2
        assert validator_from_db.blocks_validated == validator_2.blocks_validated + 1
      end
    end
  end

  describe "start_fetch_and_import" do
    @tag :no_geth
    test "reorg", %{
      block_fetcher: block_fetcher,
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      initial_env = Application.get_all_env(:indexer)

      on_exit(fn ->
        Application.delete_env(:indexer, UncleBlock.Supervisor)
        Application.put_all_env([{:indexer, initial_env}])
      end)

      Application.put_env(:indexer, :fetch_rewards_way, "manual")
      Application.put_env(:indexer, InternalTransaction.Supervisor, disabled?: true)
      Application.put_env(:indexer, UncleBlock.Supervisor, disabled?: true)

      start_supervised!({Task.Supervisor, name: Realtime.TaskSupervisor})

      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      ContractCode.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      ReplacedTransaction.Supervisor.Case.start_supervised!()

      block_1_data = %{
        "author" => "0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2",
        "difficulty" => "0xfffffffffffffffffffffffffffffffe",
        "extraData" => "0xd583010b088650617269747986312e32372e32826c69",
        "gasLimit" => "0x7a1200",
        "gasUsed" => "0x2886e",
        "hash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
        "logsBloom" =>
          "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "miner" => "0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2",
        "number" => "0x3c365f",
        "parentHash" => "0x57f6d66e07488defccd5216c4d2968dd6afd3bd32415e284de3b02af6535e8dc",
        "receiptsRoot" => "0x111be72e682cea9c93e02f1ef503fb64aa821b2ef510fd9177c49b37d0af98b5",
        "sealFields" => [
          "0x841246c63f",
          "0xb841ba3d11db672fd7893d1b7906275fa7c4c7f4fbcc8fa29eab0331480332361516545ef10a36d800ad2be2b449dde8d5703125156a9cf8a035f5a8623463e051b700"
        ],
        "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
        "signature" =>
          "ba3d11db672fd7893d1b7906275fa7c4c7f4fbcc8fa29eab0331480332361516545ef10a36d800ad2be2b449dde8d5703125156a9cf8a035f5a8623463e051b700",
        "size" => "0x33e",
        "stateRoot" => "0x7f73f5fb9f891213b671356126c31e9795d038844392c7aa8800ed4f52307209",
        "step" => "306628159",
        "timestamp" => "0x5b61df3b",
        "totalDifficulty" => "0x3c365effffffffffffffffffffffffed7f0362",
        "transactions" => [],
        "transactionsRoot" => "0xd7c39a93eafe0bdcbd1324c13dcd674bed8c9fa8adbf8f95bf6a59788985da6f",
        "uncles" => ["0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cd"]
      }

      block_2_data = %{
        "author" => "0x66c9343c7e8ca673a1fedf9dbf2cd7936dbbf7e3",
        "difficulty" => "0xfffffffffffffffffffffffffffffffe",
        "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
        "gasLimit" => "0x7a1200",
        "gasUsed" => "0x0",
        "hash" => "0xfb483e511d316fa4072694da3f7abc94b06286406af45061e5e681395bdc6815",
        "logsBloom" =>
          "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "miner" => "0x66c9343c7e8ca673a1fedf9dbf2cd7936dbbf7e3",
        "number" => "0x3c3660",
        "parentHash" => "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cc",
        "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        "sealFields" => [
          "0x841246c640",
          "0xb84114db3fd7526b7ea3635f5c85c30dd8a645453aa2f8afe5fd33fe0ec663c9c7b653b0fb5d8dc7d0b809674fa9dca9887d1636a586bf62191da22255eb068bf20800"
        ],
        "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
        "signature" =>
          "14db3fd7526b7ea3635f5c85c30dd8a645453aa2f8afe5fd33fe0ec663c9c7b653b0fb5d8dc7d0b809674fa9dca9887d1636a586bf62191da22255eb068bf20800",
        "size" => "0x243",
        "stateRoot" => "0x3174c461989e9f99e08fa9b4ffb8bce8d9a281c8fc9f80694bb9d3acd4f15559",
        "step" => "306628160",
        "timestamp" => "0x5b61df40",
        "totalDifficulty" => "0x3c365fffffffffffffffffffffffffed7f0360",
        "transactions" => [],
        "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        "uncles" => []
      }

      reorg_block_1_data =
        Map.put(block_1_data, "hash", "0xa4ec735cabe1510b5ae081b30f17222580b4588dbec52830529753a688b046cd")

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, 6, fn
          [
            %{
              id: 0,
              jsonrpc: "2.0",
              method: "eth_getBlockByNumber",
              params: ["0x3C365F", true]
            }
          ],
          _ ->
            {:ok,
             [
               %{
                 id: 0,
                 jsonrpc: "2.0",
                 result: block_1_data
               }
             ]}

          [
            %{
              id: 0,
              jsonrpc: "2.0",
              method: "eth_getBlockByNumber",
              params: ["0x3C3660", true]
            }
          ],
          _ ->
            {:ok,
             [
               %{
                 id: 0,
                 jsonrpc: "2.0",
                 result: block_2_data
               }
             ]}

          [
            %{
              id: 0,
              jsonrpc: "2.0",
              method: "eth_getBalance",
              params: ["0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2", "0x3C365F"]
            }
          ],
          _ ->
            {:ok, [%{id: 0, jsonrpc: "2.0", result: "0x53474fa377a46000"}]}

          [
            %{
              id: 0,
              jsonrpc: "2.0",
              method: "eth_getBalance",
              params: ["0x66c9343c7e8ca673a1fedf9dbf2cd7936dbbf7e3", "0x3C3660"]
            }
          ],
          _ ->
            {:ok, [%{id: 0, jsonrpc: "2.0", result: "0x53507afe51f28000"}]}
        end)
        |> expect(:json_rpc, 3, fn
          [
            %{
              id: 0,
              jsonrpc: "2.0",
              method: "eth_getBlockByNumber",
              params: ["0x3C365F", true]
            }
          ],
          _ ->
            {:ok,
             [
               %{
                 id: 0,
                 jsonrpc: "2.0",
                 result: reorg_block_1_data
               }
             ]}

          [
            %{
              id: 0,
              jsonrpc: "2.0",
              method: "eth_getBalance",
              params: ["0x5ee341ac44d344ade1ca3a771c59b98eb2a77df2", "0x3C365F"]
            }
          ],
          _ ->
            {:ok, [%{id: 0, jsonrpc: "2.0", result: "0x53474fa377a46000"}]}
        end)
      end

      Realtime.Fetcher.start_fetch_and_import(3_946_080, block_fetcher, 3_946_078)
      Process.sleep(1000)

      result_blocks = Explorer.Repo.all(Chain.Block)
      assert [%{consensus: true}, %{consensus: true}] = result_blocks

      block_1 = Enum.find(result_blocks, fn block -> block.number == 3_946_079 end)
      block_2 = Enum.find(result_blocks, fn block -> block.number == 3_946_080 end)
      assert to_string(block_1.hash) == block_1_data["hash"]
      assert to_string(block_2.hash) == block_2_data["hash"]

      Realtime.Fetcher.start_fetch_and_import(3_946_079, block_fetcher, 3_946_080)
      Process.sleep(6000)

      result_blocks = Explorer.Repo.all(Chain.Block)
      assert Enum.count(result_blocks) == 3

      block_1_old = Enum.find(result_blocks, fn block -> to_string(block.hash) == block_1_data["hash"] end)
      block_2_old = Enum.find(result_blocks, fn block -> to_string(block.hash) == block_2_data["hash"] end)
      block_1_new = Enum.find(result_blocks, fn block -> to_string(block.hash) == reorg_block_1_data["hash"] end)
      assert %{consensus: false} = block_1_old
      assert %{consensus: false} = block_2_old
      assert %{consensus: true} = block_1_new
    end
  end
end
