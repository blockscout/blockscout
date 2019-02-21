defmodule Indexer.Block.FetcherTest do
  # `async: false` due to use of named GenServer
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox
  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  import EthereumJSONRPC.Case

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Log, Transaction, Wei}
  alias Indexer.{CoinBalance, BufferedTask, Code, InternalTransaction, ReplacedTransaction, Token, TokenBalance}
  alias Indexer.Block.{Fetcher, Uncle}

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

  describe "import_range/2" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Code.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      ReplacedTransaction.Supervisor.Case.start_supervised!()

      Uncle.Supervisor.Case.start_supervised!(
        block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments}
      )

      %{
        block_fetcher: %Fetcher{
          broadcast: false,
          callback_module: Indexer.Block.Catchup.Fetcher,
          json_rpc_named_arguments: json_rpc_named_arguments
        }
      }
    end

    test "with single element range that is valid imports one block", %{
      block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher
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
            |> expect(:json_rpc, fn [%{id: id, method: "trace_block", params: [^block_quantity]}], _options ->
              {:ok, [%{id: id, result: []}]}
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
        fn -> Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number) end,
        fn result ->
          assert {:ok,
                  %{
                    inserted: %{
                      addresses: [%Address{hash: ^address_hash}],
                      blocks: [%Chain.Block{hash: ^block_hash}]
                    },
                    errors: []
                  }} = result

          wait_for_tasks(InternalTransaction.Fetcher)
          wait_for_tasks(CoinBalance.Fetcher)

          assert Repo.aggregate(Chain.Block, :count, :hash) == 1
          assert Repo.aggregate(Address, :count, :hash) == 1

          address = Repo.get!(Address, address_hash)

          assert address.fetched_coin_balance == %Wei{value: Decimal.new(0)}
          assert address.fetched_coin_balance_block_number == 0
        end
      )
    end

    # We can't currently index the whole Ethereum Mainnet, so we don't know what is the first full block.
    #   Implement when a full block is found for Ethereum Mainnet and remove :no_geth tag
    @tag :no_geth
    test "can import range with all synchronous imported schemas", %{
      block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher
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
            |> expect(:json_rpc, fn [%{id: id, method: "trace_block", params: [^block_quantity]}], _options ->
              {:ok, [%{id: id, result: []}]}
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
                      %Transaction{
                        block_number: block_number,
                        index: 0,
                        hash: %Explorer.Chain.Hash{
                          byte_count: 32,
                          bytes:
                            <<76, 188, 236, 37, 153, 153, 224, 115, 252, 79, 176, 224, 228, 166, 18, 66, 94, 61, 115,
                              57, 47, 162, 37, 255, 36, 96, 161, 238, 171, 66, 99, 10>>
                        },
                        internal_transactions_indexed_at: nil
                      },
                      %Transaction{
                        block_number: block_number,
                        index: 1,
                        hash: %Explorer.Chain.Hash{
                          byte_count: 32,
                          bytes:
                            <<240, 237, 34, 44, 16, 174, 248, 135, 4, 196, 15, 198, 34, 220, 218, 174, 13, 208, 242,
                              122, 154, 143, 4, 28, 171, 95, 190, 255, 254, 174, 75, 182>>
                        },
                        internal_transactions_indexed_at: nil
                      }
                    ]
                  }} = Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number)

          wait_for_tasks(InternalTransaction.Fetcher)
          wait_for_tasks(CoinBalance.Fetcher)

          assert Repo.aggregate(Block, :count, :hash) == 1
          assert Repo.aggregate(Address, :count, :hash) == 5
          assert Repo.aggregate(Log, :count, :id) == 0
          assert Repo.aggregate(Transaction, :count, :hash) == 2

          first_address = Repo.get!(Address, first_address_hash)

          assert first_address.fetched_coin_balance == %Wei{value: Decimal.new(1_999_953_415_287_753_599_000)}
          assert first_address.fetched_coin_balance_block_number == block_number

          second_address = Repo.get!(Address, second_address_hash)

          assert second_address.fetched_coin_balance == %Wei{value: Decimal.new(50_000_000_000_000_000)}
          assert second_address.fetched_coin_balance_block_number == block_number

          third_address = Repo.get!(Address, third_address_hash)

          assert third_address.fetched_coin_balance == %Wei{value: Decimal.new(30_827_986_037_499_360_709_544)}
          assert third_address.fetched_coin_balance_block_number == block_number

          fourth_address = Repo.get!(Address, fourth_address_hash)

          assert fourth_address.fetched_coin_balance == %Wei{value: Decimal.new(500_000_000_001_437_727_304)}
          assert fourth_address.fetched_coin_balance_block_number == block_number

          fifth_address = Repo.get!(Address, fifth_address_hash)

          assert fifth_address.fetched_coin_balance == %Wei{value: Decimal.new(930_417_572_224_879_702_000)}
          assert fifth_address.fetched_coin_balance_block_number == block_number

        EthereumJSONRPC.Parity ->
          assert {:ok,
                  %{
                    inserted: %{
                      addresses: [
                        %Address{
                          hash:
                            %Explorer.Chain.Hash{
                              byte_count: 20,
                              bytes:
                                <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179,
                                  223, 65, 91>>
                            } = first_address_hash
                        },
                        %Address{
                          hash:
                            %Explorer.Chain.Hash{
                              byte_count: 20,
                              bytes:
                                <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152,
                                  122, 202>>
                            } = second_address_hash
                        }
                      ],
                      blocks: [
                        %Chain.Block{
                          hash: %Explorer.Chain.Hash{
                            byte_count: 32,
                            bytes:
                              <<246, 180, 184, 200, 141, 243, 235, 210, 82, 236, 71, 99, 40, 51, 77, 192, 38, 207, 102,
                                96, 106, 132, 251, 118, 155, 61, 60, 188, 204, 132, 113, 189>>
                          }
                        }
                      ],
                      logs: [
                        %Log{
                          index: 0,
                          transaction_hash: %Explorer.Chain.Hash{
                            byte_count: 32,
                            bytes:
                              <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35,
                                77, 57, 101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                          }
                        }
                      ],
                      transactions: [
                        %Transaction{
                          block_number: block_number,
                          index: 0,
                          hash: %Explorer.Chain.Hash{
                            byte_count: 32,
                            bytes:
                              <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35,
                                77, 57, 101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                          },
                          internal_transactions_indexed_at: nil
                        }
                      ]
                    },
                    errors: []
                  }} = Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number)

          wait_for_tasks(InternalTransaction.Fetcher)
          wait_for_tasks(CoinBalance.Fetcher)

          assert Repo.aggregate(Chain.Block, :count, :hash) == 1
          assert Repo.aggregate(Address, :count, :hash) == 2
          assert Chain.log_count() == 1
          assert Repo.aggregate(Transaction, :count, :hash) == 1

          first_address = Repo.get!(Address, first_address_hash)

          assert first_address.fetched_coin_balance == %Wei{value: Decimal.new(1)}
          assert first_address.fetched_coin_balance_block_number == block_number

          second_address = Repo.get!(Address, second_address_hash)

          assert second_address.fetched_coin_balance == %Wei{value: Decimal.new(252_460_837_000_000_000_000_000_000)}
          assert second_address.fetched_coin_balance_block_number == block_number

        variant ->
          raise ArgumentError, "Unsupported variant (#{variant})"
      end
    end
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
    wait_until(:timer.seconds(10), fn ->
      counts = BufferedTask.debug_count(buffered_task)
      counts.buffer == 0 and counts.tasks == 0
    end)
  end
end
