defmodule Indexer.Block.FetcherTest do
  # `async: false` due to use of named GenServer
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox
  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  import Explorer.Celo.CacheHelper

  alias Explorer.Celo.{CoreContracts, Events}
  alias Explorer.Chain
  alias Explorer.Chain.{Address, CeloPendingEpochOperation, CeloUnlocked, Log, Transaction, Wei}
  alias Indexer.Block.Fetcher
  alias Indexer.BufferedTask
  alias Indexer.Celo.TrackedEventCache

  alias Indexer.Fetcher.{
    CoinBalance,
    ContractCode,
    InternalTransaction,
    ReplacedTransaction,
    Token,
    TokenBalance,
    UncleBlock,
    EventProcessor,
    CeloAccount,
    CeloValidator,
    CeloValidatorHistory,
    CeloValidatorGroup,
    CeloEpochData,
    CeloVoters
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

  describe "import_range/2" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      ContractCode.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      CeloAccount.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      CeloValidator.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      CeloValidatorHistory.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      CeloValidatorGroup.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      CeloVoters.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      CeloEpochData.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      ReplacedTransaction.Supervisor.Case.start_supervised!()
      start_supervised!({TrackedEventCache, [%{}, []]})
      EventProcessor.Supervisor.Case.start_supervised!()

      UncleBlock.Supervisor.Case.start_supervised!(
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

    # We can't currently index the whole Ethereum Mainnet, so we don't know what is the first full block.
    #   Implement when a full block is found for Ethereum Mainnet and remove :no_geth tag
    @tag :no_geth
    test "can import range with all synchronous imported schemas", %{
      block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher
    } do
      celo_token_address = insert(:contract_address)
      insert(:token, contract_address: celo_token_address)

      "0x" <> unprefixed_celo_token_address_hash = to_string(celo_token_address.hash)
      set_test_address(to_string(celo_token_address.hash))

      block_number = @first_full_block_number

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Nethermind ->
            block_quantity = integer_to_quantity(block_number)
            from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
            to_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
            transaction_hash = "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
            [event_first_topic] = Events.gold_withdrawn()
            event_data = "0x0000000000000000000000000000000000000000000000000000000000000f00"

            setup_mox(
              block_quantity,
              from_address_hash,
              to_address_hash,
              transaction_hash,
              unprefixed_celo_token_address_hash,
              event_first_topic,
              event_data,
              17
            )

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
                        bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
                      },
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
                        }
                      },
                      %Transaction{
                        block_number: block_number,
                        index: 1,
                        hash: %Explorer.Chain.Hash{
                          byte_count: 32,
                          bytes:
                            <<240, 237, 34, 44, 16, 174, 248, 135, 4, 196, 15, 198, 34, 220, 218, 174, 13, 208, 242,
                              122, 154, 143, 4, 28, 171, 95, 190, 255, 254, 174, 75, 182>>
                        }
                      }
                    ]
                  }} = Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number)

          wait_for_tasks(InternalTransaction)
          wait_for_tasks(CoinBalance)

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

        EthereumJSONRPC.Nethermind ->
          assert {:ok,
                  %{
                    inserted: %{
                      addresses: [
                        %Address{
                          hash: %Explorer.Chain.Hash{
                            byte_count: 20,
                            bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
                          }
                        },
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
                          }
                        }
                      ]
                    },
                    errors: []
                  }} = Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number)

          wait_for_tasks(InternalTransaction)
          wait_for_tasks(CoinBalance)

          assert Repo.aggregate(Chain.Block, :count, :hash) == 1
          assert Repo.aggregate(Address, :count, :hash) == 4
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

    @tag :no_geth
    test "inserts an entry to unlocked celo in case of a gold_unlocked event", %{
      block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher
    } do
      celo_token_address = insert(:contract_address)
      insert(:token, contract_address: celo_token_address)
      "0x" <> unprefixed_celo_token_address_hash = to_string(celo_token_address.hash)
      set_test_address(to_string(celo_token_address.hash))

      block_number = @first_full_block_number

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Nethermind ->
            block_quantity = integer_to_quantity(block_number)
            from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
            to_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
            transaction_hash = "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
            [event_first_topic] = Events.gold_unlocked()

            event_data =
              "0x00000000000000000000000000000000000000000000001aabdf2145b43000000000000000000000000000000000000000000000000000000000000061b2bcf8"

            setup_mox(
              block_quantity,
              from_address_hash,
              to_address_hash,
              transaction_hash,
              unprefixed_celo_token_address_hash,
              event_first_topic,
              event_data,
              18
            )

          variant ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end
      end

      case Keyword.fetch!(json_rpc_named_arguments, :variant) do
        EthereumJSONRPC.Nethermind ->
          assert {:ok,
                  %{
                    inserted: %{
                      addresses: [
                        %Address{
                          hash: %Explorer.Chain.Hash{
                            byte_count: 20,
                            bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
                          }
                        },
                        %Address{
                          hash: %Explorer.Chain.Hash{
                            byte_count: 20,
                            bytes:
                              <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223,
                                65, 91>>
                          }
                        },
                        %Address{
                          hash: %Explorer.Chain.Hash{
                            byte_count: 20,
                            bytes:
                              <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152,
                                122, 202>>
                          }
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
                          block_number: _,
                          index: 0,
                          hash: %Explorer.Chain.Hash{
                            byte_count: 32,
                            bytes:
                              <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35,
                                77, 57, 101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                          }
                        }
                      ]
                    },
                    errors: []
                  }} = Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number)

          wait_for_tasks(InternalTransaction)
          wait_for_tasks(CoinBalance)

          assert Repo.aggregate(CeloUnlocked, :count, :account_address) == 1

        variant ->
          raise ArgumentError, "Unsupported variant (#{variant})"
      end
    end

    @tag :skip
    test "deletes the entry in unlocked celo in case of a gold_withdrawn event", %{
      block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher
    } do
      celo_token_address = insert(:contract_address)
      insert(:token, contract_address: celo_token_address)
      "0x" <> unprefixed_celo_token_address_hash = to_string(celo_token_address.hash)
      set_test_address(to_string(celo_token_address.hash))

      block_number = @first_full_block_number
      insert(:celo_unlocked, %{account_address: "0xC257274276a4E539741Ca11b590B9447B26A8051", amount: 3840})

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Nethermind ->
            block_quantity = integer_to_quantity(block_number)
            from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
            to_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
            transaction_hash = "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
            [event_first_topic] = Events.gold_withdrawn()
            event_data = ""

            setup_mox(
              block_quantity,
              from_address_hash,
              to_address_hash,
              transaction_hash,
              unprefixed_celo_token_address_hash,
              event_first_topic,
              event_data,
              18
            )

          variant ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end
      end

      case Keyword.fetch!(json_rpc_named_arguments, :variant) do
        EthereumJSONRPC.Nethermind ->
          assert {:ok,
                  %{
                    inserted: %{
                      addresses: [
                        %Address{
                          hash: %Explorer.Chain.Hash{
                            byte_count: 20,
                            bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
                          }
                        },
                        %Address{
                          hash: %Explorer.Chain.Hash{
                            byte_count: 20,
                            bytes:
                              <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223,
                                65, 91>>
                          }
                        },
                        %Address{
                          hash: %Explorer.Chain.Hash{
                            byte_count: 20,
                            bytes:
                              <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152,
                                122, 202>>
                          }
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
                          block_number: _,
                          index: 0,
                          hash: %Explorer.Chain.Hash{
                            byte_count: 32,
                            bytes:
                              <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35,
                                77, 57, 101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                          }
                        }
                      ]
                    },
                    errors: []
                  }} = Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number)

          wait_for_tasks(InternalTransaction)
          wait_for_tasks(CoinBalance)

          assert Repo.aggregate(CeloUnlocked, :count, :account_address) == 0

        variant ->
          raise ArgumentError, "Unsupported variant (#{variant})"
      end
    end

    @tag :no_geth
    test "correctly imports blocks with multiple uncle rewards for the same address", %{
      block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher
    } do
      celo_token_address = insert(:contract_address)
      insert(:token, contract_address: celo_token_address)
      "0x" <> unprefixed_celo_token_address_hash = to_string(celo_token_address.hash)
      set_test_address(to_string(celo_token_address.hash))

      block_number = 7_374_455

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, 3, fn requests, _options ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_getBlockByNumber", params: ["0x708677", true]} ->
               %{
                 id: id,
                 result: %{
                   "author" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                   "difficulty" => "0x6bc767dd80781",
                   "extraData" => "0x5050594520737061726b706f6f6c2d6574682d7477",
                   "gasLimit" => "0x7a121d",
                   "gasUsed" => "0x79cbe9",
                   "hash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                   "logsBloom" =>
                     "0x044d42d008801488400e1809190200a80d06105bc0c4100b047895c0d518327048496108388040140010b8208006288102e206160e21052322440924002090c1c808a0817405ab238086d028211014058e949401012403210314896702d06880c815c3060a0f0809987c81044488292cc11d57882c912a808ca10471c84460460040000c0001012804022000a42106591881d34407420ba401e1c08a8d00a000a34c11821a80222818a4102152c8a0c044032080c6462644223104d618e0e544072008120104408205c60510542264808488220403000106281a0290404220112c10b080145028c8000300b18a2c8280701c882e702210b00410834840108084",
                   "miner" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                   "mixHash" => "0xda53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                   "nonce" => "0x0946e5f01fce12bc",
                   "number" => "0x708677",
                   "parentHash" => "0x62543e836e0ef7edfa9e38f26526092c4be97efdf5ba9e0f53a4b0b7d5bc930a",
                   "receiptsRoot" => "0xa7d2b82bd8526de11736c18bd5cc8cfe2692106c4364526f3310ad56d78669c4",
                   "sealFields" => [
                     "0xa0da53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                     "0x880946e5f01fce12bc"
                   ],
                   "sha3Uncles" => "0x483a8a21a5825ad270f358b3ea56e060bbb8b3082d9a92ec8fa17a5c7e6fc1b6",
                   "size" => "0x544c",
                   "stateRoot" => "0x85daa9cd528004c1609d4cb3520fd958e85983bb4183124a4a9f7137fd39c691",
                   "timestamp" => "0x5c8bc76e",
                   "totalDifficulty" => "0x201a42c35142ae94458",
                   "transactions" => [],
                   "transactionsRoot" => "0xcd6c12fa43cd4e92ad5c0bf232b30488bbcbfe273c5b4af0366fced0767d54db",
                   "uncles" => []
                 }
               }

             %{id: id, jsonrpc: "2.0", method: "eth_getLogs"} ->
               %{id: id, jsonrpc: "2.0", result: []}

             %{id: id, method: "trace_block"} ->
               block_quantity = integer_to_quantity(block_number)
               _res = eth_block_number_fake_response(block_quantity)

               %{
                 id: id,
                 result: [
                   %{
                     "action" => %{
                       "author" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                       "rewardType" => "block",
                       "value" => "0x1d7d843dc3b48000"
                     },
                     "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                     "blockNumber" => block_number,
                     "subtraces" => 0,
                     "traceAddress" => [],
                     "type" => "reward"
                   },
                   %{
                     "action" => %{
                       "author" => "0xea674fdde714fd979de3edf0f56aa9716b898ec8",
                       "rewardType" => "uncle",
                       "value" => "0x14d1120d7b160000"
                     },
                     "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                     "blockNumber" => block_number,
                     "subtraces" => 0,
                     "traceAddress" => [],
                     "type" => "reward"
                   },
                   %{
                     "action" => %{
                       "author" => "0xea674fdde714fd979de3edf0f56aa9716b898ec8",
                       "rewardType" => "uncle",
                       "value" => "0x18493fba64ef0000"
                     },
                     "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                     "blockNumber" => block_number,
                     "subtraces" => 0,
                     "traceAddress" => [],
                     "type" => "reward"
                   }
                 ]
               }
           end)}
        end)
      end

      assert {:ok, %{errors: [], inserted: %{block_rewards: _block_rewards}}} =
               Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number)

      assert Repo.one!(select(Chain.Block.Reward, fragment("COUNT(*)"))) == 2
    end

    test "imports blocks with legacy (type 0x0) transactions", %{
      block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher
    } do
      celo_token_address = insert(:contract_address)
      insert(:token, contract_address: celo_token_address)
      "0x" <> unprefixed_celo_token_address_hash = to_string(celo_token_address.hash)
      set_test_address(to_string(celo_token_address.hash))

      block_number = 7
      from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      to_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      transaction_hash = "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, 4, fn requests, _options ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_getBlockByNumber", params: ["0x7", true]} ->
               %{
                 id: id,
                 result: %{
                   "author" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                   "difficulty" => "0x6bc767dd80781",
                   "extraData" => "0x5050594520737061726b706f6f6c2d6574682d7477",
                   "gasLimit" => "0x7a121d",
                   "gasUsed" => "0x79cbe9",
                   "hash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                   "logsBloom" =>
                     "0x044d42d008801488400e1809190200a80d06105bc0c4100b047895c0d518327048496108388040140010b8208006288102e206160e21052322440924002090c1c808a0817405ab238086d028211014058e949401012403210314896702d06880c815c3060a0f0809987c81044488292cc11d57882c912a808ca10471c84460460040000c0001012804022000a42106591881d34407420ba401e1c08a8d00a000a34c11821a80222818a4102152c8a0c044032080c6462644223104d618e0e544072008120104408205c60510542264808488220403000106281a0290404220112c10b080145028c8000300b18a2c8280701c882e702210b00410834840108084",
                   "miner" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                   "mixHash" => "0xda53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                   "nonce" => "0x0946e5f01fce12bc",
                   "number" => "0x7",
                   "parentHash" => "0x62543e836e0ef7edfa9e38f26526092c4be97efdf5ba9e0f53a4b0b7d5bc930a",
                   "receiptsRoot" => "0xa7d2b82bd8526de11736c18bd5cc8cfe2692106c4364526f3310ad56d78669c4",
                   "sha3Uncles" => "0x483a8a21a5825ad270f358b3ea56e060bbb8b3082d9a92ec8fa17a5c7e6fc1b6",
                   "size" => "0x544c",
                   "stateRoot" => "0x85daa9cd528004c1609d4cb3520fd958e85983bb4183124a4a9f7137fd39c691",
                   "timestamp" => "0x5c8bc76e",
                   "totalDifficulty" => "0x201a42c35142ae94458",
                   "transactions" => [
                     %{
                       "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                       "blockNumber" => "0x7",
                       "chainId" => "0x4d",
                       "from" => from_address_hash,
                       "gas" => "0x47b760",
                       "gasPrice" => "0x174876e800",
                       "feeCurrency" => nil,
                       "gatewayFeeRecipient" => nil,
                       "gatewayFee" => "0x0",
                       "hash" => transaction_hash,
                       "input" => "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                       "nonce" => "0x4",
                       "r" => "0xa7f8f45cce375bb7af8750416e1b03e0473f93c256da2285d1134fc97a700e01",
                       "s" => "0x1f87a076f13824f4be8963e3dffd7300dae64d5f23c9a062af0c6ead347c135f",
                       "to" => to_address_hash,
                       "transactionIndex" => "0x0",
                       "type" => "0x0",
                       "v" => "0xbe",
                       "value" => "0x0"
                     }
                   ],
                   "transactionsRoot" => "0xcd6c12fa43cd4e92ad5c0bf232b30488bbcbfe273c5b4af0366fced0767d54db",
                   "uncles" => []
                 }
               }

             %{
               id: id,
               method: "eth_getTransactionReceipt",
               params: [^transaction_hash]
             } ->
               %{
                 id: id,
                 jsonrpc: "2.0",
                 result: %{
                   "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                   "blockNumber" => "0x7",
                   "contractAddress" => nil,
                   "cumulativeGasUsed" => "0xc512",
                   "gasUsed" => "0xc512",
                   "logs" => [
                     %{
                       "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
                       "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                       "blockNumber" => "0x7",
                       "data" => "0x0000000000000000000000000000000000000000000000000000000000000f00",
                       "logIndex" => "0x0",
                       "topics" => [
                         "0x000000000000000000000000C257274276a4E539741Ca11b590B9447B26A8051"
                       ],
                       "transactionHash" => transaction_hash,
                       "transactionIndex" => "0x0",
                       "transactionLogIndex" => "0x0",
                       "type" => "mined"
                     }
                   ],
                   "logsBloom" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                   "root" => nil,
                   "status" => "0x1",
                   "transactionHash" => transaction_hash,
                   "transactionIndex" => "0x0"
                 }
               }

             %{id: id, method: "trace_block", params: [_]} ->
               %{id: id, result: []}

             %{id: id, jsonrpc: "2.0", method: "eth_getLogs"} ->
               %{id: id, jsonrpc: "2.0", result: []}
           end)}
        end)
      end

      assert {:ok, %{inserted: inserted}} = Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number)

      assert %{transactions: [transaction]} = inserted
      assert transaction.type == 0

      # fetch from db for ultimate anti paranoia check
      t = Transaction |> where([t], t.hash == ^transaction_hash) |> Explorer.Repo.one()
      assert t.type == 0
    end

    test "imports celo contracts and celo contract events", %{
      block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher
    } do
      celo_token_address = insert(:contract_address)
      insert(:token, contract_address: celo_token_address)
      "0x" <> unprefixed_celo_token_address_hash = to_string(celo_token_address.hash)
      set_test_address(to_string(celo_token_address.hash))

      core_contract = insert(:core_contract)

      [core_contract.address_hash() |> to_string()]
      |> MapSet.new()
      |> set_cache_address_set()

      expected_new_core_contract_name = "AwesomeNewCoreContract"
      expected_new_core_contract_address = "0x0000000000000000000000000000000000007777"

      Explorer.Celo.AddressCache.Mock
      |> Mox.expect(:update_cache, fn
        ^expected_new_core_contract_name, ^expected_new_core_contract_address -> nil
      end)

      block_number = 7
      from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      to_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      transaction_hash = "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
      max_fee_per_gas = 78_787_878
      max_priority_fee_per_gas = 67_676_767

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, 4, fn requests, _options ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_getBlockByNumber", params: ["0x7", true]} ->
               %{
                 id: id,
                 result: %{
                   "author" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                   "difficulty" => "0x6bc767dd80781",
                   "extraData" => "0x5050594520737061726b706f6f6c2d6574682d7477",
                   "gasLimit" => "0x7a121d",
                   "gasUsed" => "0x79cbe9",
                   "hash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                   "logsBloom" =>
                     "0x044d42d008801488400e1809190200a80d06105bc0c4100b047895c0d518327048496108388040140010b8208006288102e206160e21052322440924002090c1c808a0817405ab238086d028211014058e949401012403210314896702d06880c815c3060a0f0809987c81044488292cc11d57882c912a808ca10471c84460460040000c0001012804022000a42106591881d34407420ba401e1c08a8d00a000a34c11821a80222818a4102152c8a0c044032080c6462644223104d618e0e544072008120104408205c60510542264808488220403000106281a0290404220112c10b080145028c8000300b18a2c8280701c882e702210b00410834840108084",
                   "miner" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                   "mixHash" => "0xda53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                   "nonce" => "0x0946e5f01fce12bc",
                   "number" => "0x7",
                   "parentHash" => "0x62543e836e0ef7edfa9e38f26526092c4be97efdf5ba9e0f53a4b0b7d5bc930a",
                   "receiptsRoot" => "0xa7d2b82bd8526de11736c18bd5cc8cfe2692106c4364526f3310ad56d78669c4",
                   "sha3Uncles" => "0x483a8a21a5825ad270f358b3ea56e060bbb8b3082d9a92ec8fa17a5c7e6fc1b6",
                   "size" => "0x544c",
                   "stateRoot" => "0x85daa9cd528004c1609d4cb3520fd958e85983bb4183124a4a9f7137fd39c691",
                   "timestamp" => "0x5c8bc76e",
                   "totalDifficulty" => "0x201a42c35142ae94458",
                   "transactions" => [
                     %{
                       "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                       "blockNumber" => "0x7",
                       "chainId" => "0x4d",
                       "from" => from_address_hash,
                       "gas" => "0x47b760",
                       "gasPrice" => "0x174876e800",
                       "feeCurrency" => nil,
                       "gatewayFeeRecipient" => nil,
                       "gatewayFee" => "0x0",
                       "hash" => transaction_hash,
                       "input" => "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                       "maxFeePerGas" => max_fee_per_gas,
                       "maxPriorityFeePerGas" => max_priority_fee_per_gas,
                       "nonce" => "0x4",
                       "r" => "0xa7f8f45cce375bb7af8750416e1b03e0473f93c256da2285d1134fc97a700e01",
                       "s" => "0x1f87a076f13824f4be8963e3dffd7300dae64d5f23c9a062af0c6ead347c135f",
                       "to" => to_address_hash,
                       "transactionIndex" => "0x0",
                       "type" => "0x2",
                       "v" => "0xbe",
                       "value" => "0x0"
                     }
                   ],
                   "transactionsRoot" => "0xcd6c12fa43cd4e92ad5c0bf232b30488bbcbfe273c5b4af0366fced0767d54db",
                   "uncles" => []
                 }
               }

             %{
               id: id,
               method: "eth_getTransactionReceipt",
               params: [^transaction_hash]
             } ->
               %{
                 id: id,
                 jsonrpc: "2.0",
                 result: %{
                   "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                   "blockNumber" => "0x7",
                   "contractAddress" => nil,
                   "cumulativeGasUsed" => "0xc512",
                   "gasUsed" => "0xc512",
                   "logs" => [
                     %{
                       "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
                       "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                       "blockNumber" => "0x7",
                       "data" => "0x0000000000000000000000000000000000000000000000000000000000000f00",
                       "logIndex" => "0x0",
                       "topics" => [
                         "0x000000000000000000000000c257274276a4e539741ca11b590b9447b26a8051"
                       ],
                       "transactionHash" => transaction_hash,
                       "transactionIndex" => "0x0",
                       "transactionLogIndex" => "0x0",
                       "type" => "mined"
                     },
                     %{
                       "address" => "0x0000000000000000000000000000000000000000",
                       "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                       "blockNumber" => "0x7",
                       "data" => "0x0000000000000000000000000000000000000000000000000000000000000f00",
                       "logIndex" => "0x1",
                       "topics" => [
                         # ValidatorGroupVoteActivated
                         "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe",
                         "0x00000000000000000000000088c1c759600ec3110af043c183a2472ab32d099c",
                         "0x00000000000000000000000047b2db6af05a55d42ed0f3731735f9479abf0673"
                       ],
                       "transactionHash" => transaction_hash,
                       "transactionIndex" => "0x0",
                       "transactionLogIndex" => "0x1",
                       "type" => "mined"
                     },
                     %{
                       "address" => core_contract.address_hash() |> to_string(),
                       "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                       "blockNumber" => "0x7",
                       "data" =>
                         "0x000000000000000000000000000000000000000000000003a188c31fefaa000000000000000000000000000000000012086cd1c417618770935790ad714d7730",
                       "logIndex" => "0x2",
                       "topics" => [
                         # ValidatorGroupActiveVoteRevoked
                         "0xae7458f8697a680da6be36406ea0b8f40164915ac9cc40c0dad05a2ff6e8c6a8",
                         "0x00000000000000000000000088c1c759600ec3110af043c183a2472ab32d099c",
                         "0x00000000000000000000000047b2db6af05a55d42ed0f3731735f9479abf0673"
                       ],
                       "transactionHash" => transaction_hash,
                       "transactionIndex" => "0x0",
                       "transactionLogIndex" => "0x2",
                       "type" => "mined"
                     },
                     %{
                       "address" => CoreContracts.registry_address(),
                       "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                       "blockNumber" => "0x7",
                       # ABI.encode("(string)", [{"AwesomeNewCoreContract"}]) |> Base.encode16()
                       "data" =>
                         "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000016417765736f6d654e6577436f7265436f6e747261637400000000000000000000",
                       "logIndex" => "0x4",
                       "topics" => [
                         # RegistryUpdated
                         "0x4166d073a7a5e704ce0db7113320f88da2457f872d46dc020c805c562c1582a0",
                         # identifier hash
                         "0x00000000000000000000000088c1c759600ec3110af043c183a2472ab32d099c",
                         # address
                         "0x0000000000000000000000000000000000000000000000000000000000007777"
                       ],
                       "transactionHash" => transaction_hash,
                       "transactionIndex" => "0x0",
                       "transactionLogIndex" => "0x2",
                       "type" => "mined"
                     }
                   ],
                   "logsBloom" => "0x00",
                   "root" => nil,
                   "status" => "0x1",
                   "transactionHash" => transaction_hash,
                   "transactionIndex" => "0x0"
                 }
               }

             %{id: id, method: "trace_block", params: [_]} ->
               %{id: id, result: []}

             %{id: id, jsonrpc: "2.0", method: "eth_getLogs"} ->
               %{id: id, jsonrpc: "2.0", result: []}
           end)}
        end)
      end

      assert {:ok, %{inserted: inserted}} = Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number)

      # should insert 3 logs
      assert 4 == length(inserted[:logs])
      # should insert 1 celo contract event from those logs
      assert 1 == length(inserted[:celo_contract_event])

      [event] = inserted[:celo_contract_event]

      # despite two matching contract event topics, only one log comes from an address marked as a celo core contract
      assert "ValidatorGroupActiveVoteRevoked" == event.name,
             "Only event inserted should be ValidatorGroupActiveVoteRevoked"
    end

    test "imports epoch logs", %{
      block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher
    } do
      celo_token_address = insert(:contract_address)
      insert(:token, contract_address: celo_token_address)
      "0x" <> unprefixed_celo_token_address_hash = to_string(celo_token_address.hash)
      set_test_address(to_string(celo_token_address.hash))

      core_contract = insert(:core_contract)

      contract_hash = core_contract.address_hash() |> to_string()

      [contract_hash]
      |> MapSet.new()
      |> set_cache_address_set()

      block_number = 12_216_960
      from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      to_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      transaction_hash = "0xb8a9f217d2cd318c9068c5f09ba31b3cad3219ffa7e11b0bb8a76e43d4647d29"
      max_fee_per_gas = 78_787_878
      max_priority_fee_per_gas = 67_676_767

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, 4, fn requests, _options ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_getBlockByNumber"} ->
               %{
                 id: id,
                 result: %{
                   "author" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                   "difficulty" => "0x6bc767dd80781",
                   "extraData" => "0x5050594520737061726b706f6f6c2d6574682d7477",
                   "gasLimit" => "0x7a121d",
                   "gasUsed" => "0x79cbe9",
                   "hash" => "0xb8a9f217d2cd318c9068c5f09ba31b3cad3219ffa7e11b0bb8a76e43d4647d29",
                   "logsBloom" =>
                     "0x044d42d008801488400e1809190200a80d06105bc0c4100b047895c0d518327048496108388040140010b8208006288102e206160e21052322440924002090c1c808a0817405ab238086d028211014058e949401012403210314896702d06880c815c3060a0f0809987c81044488292cc11d57882c912a808ca10471c84460460040000c0001012804022000a42106591881d34407420ba401e1c08a8d00a000a34c11821a80222818a4102152c8a0c044032080c6462644223104d618e0e544072008120104408205c60510542264808488220403000106281a0290404220112c10b080145028c8000300b18a2c8280701c882e702210b00410834840108084",
                   "miner" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                   "mixHash" => "0xda53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                   "nonce" => "0x0946e5f01fce12bc",
                   "number" => "0xBA6A80",
                   "parentHash" => "0x62543e836e0ef7edfa9e38f26526092c4be97efdf5ba9e0f53a4b0b7d5bc930a",
                   "receiptsRoot" => "0xa7d2b82bd8526de11736c18bd5cc8cfe2692106c4364526f3310ad56d78669c4",
                   "sha3Uncles" => "0x483a8a21a5825ad270f358b3ea56e060bbb8b3082d9a92ec8fa17a5c7e6fc1b6",
                   "size" => "0x544c",
                   "stateRoot" => "0x85daa9cd528004c1609d4cb3520fd958e85983bb4183124a4a9f7137fd39c691",
                   "timestamp" => "0x5c8bc76e",
                   "totalDifficulty" => "0x201a42c35142ae94458",
                   "transactions" => [
                     %{
                       "blockHash" => "0xb8a9f217d2cd318c9068c5f09ba31b3cad3219ffa7e11b0bb8a76e43d4647d29",
                       "blockNumber" => "0xBA6A80",
                       "chainId" => "0x4d",
                       "from" => from_address_hash,
                       "gas" => "0x47b760",
                       "gasPrice" => "0x174876e800",
                       "feeCurrency" => nil,
                       "gatewayFeeRecipient" => nil,
                       "gatewayFee" => "0x0",
                       "hash" => transaction_hash,
                       "input" => "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                       "maxFeePerGas" => max_fee_per_gas,
                       "maxPriorityFeePerGas" => max_priority_fee_per_gas,
                       "nonce" => "0x4",
                       "r" => "0xa7f8f45cce375bb7af8750416e1b03e0473f93c256da2285d1134fc97a700e01",
                       "s" => "0x1f87a076f13824f4be8963e3dffd7300dae64d5f23c9a062af0c6ead347c135f",
                       "to" => to_address_hash,
                       "transactionIndex" => "0x0",
                       "type" => "0x2",
                       "v" => "0xbe",
                       "value" => "0x0"
                     }
                   ],
                   "transactionsRoot" => "0xcd6c12fa43cd4e92ad5c0bf232b30488bbcbfe273c5b4af0366fced0767d54db",
                   "uncles" => []
                 }
               }

             %{
               id: id,
               method: "eth_getTransactionReceipt",
               params: [^transaction_hash]
             } ->
               %{
                 id: id,
                 jsonrpc: "2.0",
                 result: %{
                   "blockHash" => "0xb8a9f217d2cd318c9068c5f09ba31b3cad3219ffa7e11b0bb8a76e43d4647d29",
                   "blockNumber" => "0xBA6A80",
                   "contractAddress" => nil,
                   "cumulativeGasUsed" => "0xc512",
                   "gasUsed" => "0xc512",
                   "logs" => [
                     %{
                       "data" =>
                         "0x000000000000000000000000000000000000000000000007e5355cf3b8e71384000000000000000000000000000000000000000000000000e09426c5bf361e9c",
                       "logIndex" => 191,
                       "blockNumber" => 12_216_960,
                       "type" => nil,
                       "topics" => [
                         "0x6f5937add2ec38a0fa4959bccd86e3fcc2aafb706cd3e6c0565f87a7b36b9975",
                         "0x0000000000000000000000005e69cca114a77ab0a5804108faf0cd1e1c802a5e",
                         "0x000000000000000000000000614b7654ba0cc6000abe526779911b70c1f7125a"
                       ],
                       "address" => contract_hash,
                       "blockHash" => "0xb8a9f217d2cd318c9068c5f09ba31b3cad3219ffa7e11b0bb8a76e43d4647d29",
                       "transactionHash" => nil
                     },
                     %{
                       "data" =>
                         "0x000000000000000000000000000000000000000000000007e4b4652a5b982fac000000000000000000000000000000000000000000000000e085d25a0a2d5aa1",
                       "logIndex" => 194,
                       "blockNumber" => 12_216_960,
                       "type" => nil,
                       "topics" => [
                         "0x6f5937add2ec38a0fa4959bccd86e3fcc2aafb706cd3e6c0565f87a7b36b9975",
                         "0x0000000000000000000000001819b44553fa39a983d1c92238e1f18aee30ef51",
                         "0x000000000000000000000000c7d5409fee80b3ac37dbc111664dc511a5982469"
                       ],
                       "address" => contract_hash,
                       "blockHash" => "0xb8a9f217d2cd318c9068c5f09ba31b3cad3219ffa7e11b0bb8a76e43d4647d29",
                       "transactionHash" => nil
                     },
                     %{
                       "data" =>
                         "0x000000000000000000000000000000000000000000000007e53b51f062a25412000000000000000000000000000000000000000000000000e094d03727675eac",
                       "logIndex" => 197,
                       "blockNumber" => 12_216_960,
                       "type" => nil,
                       "topics" => [
                         "0x6f5937add2ec38a0fa4959bccd86e3fcc2aafb706cd3e6c0565f87a7b36b9975",
                         "0x000000000000000000000000cdd88f80ed52afec9d670f5a6da8940eee716f45",
                         "0x0000000000000000000000003d451dd723797b3de938c5b22412032b6452591a"
                       ],
                       "address" => contract_hash,
                       "blockHash" => "0xb8a9f217d2cd318c9068c5f09ba31b3cad3219ffa7e11b0bb8a76e43d4647d29",
                       "transactionHash" => nil
                     }
                   ],
                   "logsBloom" => "0x00",
                   "root" => nil,
                   "status" => "0x1",
                   "transactionHash" => transaction_hash,
                   "transactionIndex" => "0x0"
                 }
               }

             %{id: id, method: "trace_block", params: [_]} ->
               %{id: id, result: []}

             %{id: id, jsonrpc: "2.0", method: "eth_getLogs"} ->
               %{id: id, jsonrpc: "2.0", result: []}
           end)}
        end)
      end

      assert {:ok, %{inserted: inserted}} = Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number)
    end

    test "imports blocks with dynamic fee (type 0x2) transactions", %{
      block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher
    } do
      celo_token_address = insert(:contract_address)
      insert(:token, contract_address: celo_token_address)
      "0x" <> unprefixed_celo_token_address_hash = to_string(celo_token_address.hash)
      set_test_address(to_string(celo_token_address.hash))

      core_contract = insert(:core_contract)

      [core_contract.address_hash() |> to_string()]
      |> MapSet.new()
      |> set_cache_address_set()

      block_number = 7
      from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      to_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      transaction_hash = "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
      max_fee_per_gas = 78_787_878
      max_priority_fee_per_gas = 67_676_767

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, 4, fn requests, _options ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_getBlockByNumber", params: ["0x7", true]} ->
               %{
                 id: id,
                 result: %{
                   "author" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                   "difficulty" => "0x6bc767dd80781",
                   "extraData" => "0x5050594520737061726b706f6f6c2d6574682d7477",
                   "gasLimit" => "0x7a121d",
                   "gasUsed" => "0x79cbe9",
                   "hash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                   "logsBloom" =>
                     "0x044d42d008801488400e1809190200a80d06105bc0c4100b047895c0d518327048496108388040140010b8208006288102e206160e21052322440924002090c1c808a0817405ab238086d028211014058e949401012403210314896702d06880c815c3060a0f0809987c81044488292cc11d57882c912a808ca10471c84460460040000c0001012804022000a42106591881d34407420ba401e1c08a8d00a000a34c11821a80222818a4102152c8a0c044032080c6462644223104d618e0e544072008120104408205c60510542264808488220403000106281a0290404220112c10b080145028c8000300b18a2c8280701c882e702210b00410834840108084",
                   "miner" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                   "mixHash" => "0xda53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                   "nonce" => "0x0946e5f01fce12bc",
                   "number" => "0x7",
                   "parentHash" => "0x62543e836e0ef7edfa9e38f26526092c4be97efdf5ba9e0f53a4b0b7d5bc930a",
                   "receiptsRoot" => "0xa7d2b82bd8526de11736c18bd5cc8cfe2692106c4364526f3310ad56d78669c4",
                   "sha3Uncles" => "0x483a8a21a5825ad270f358b3ea56e060bbb8b3082d9a92ec8fa17a5c7e6fc1b6",
                   "size" => "0x544c",
                   "stateRoot" => "0x85daa9cd528004c1609d4cb3520fd958e85983bb4183124a4a9f7137fd39c691",
                   "timestamp" => "0x5c8bc76e",
                   "totalDifficulty" => "0x201a42c35142ae94458",
                   "transactions" => [
                     %{
                       "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                       "blockNumber" => "0x7",
                       "chainId" => "0x4d",
                       "from" => from_address_hash,
                       "gas" => "0x47b760",
                       "gasPrice" => "0x174876e800",
                       "feeCurrency" => nil,
                       "gatewayFeeRecipient" => nil,
                       "gatewayFee" => "0x0",
                       "hash" => transaction_hash,
                       "input" => "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                       "maxFeePerGas" => max_fee_per_gas,
                       "maxPriorityFeePerGas" => max_priority_fee_per_gas,
                       "nonce" => "0x4",
                       "r" => "0xa7f8f45cce375bb7af8750416e1b03e0473f93c256da2285d1134fc97a700e01",
                       "s" => "0x1f87a076f13824f4be8963e3dffd7300dae64d5f23c9a062af0c6ead347c135f",
                       "to" => to_address_hash,
                       "transactionIndex" => "0x0",
                       "type" => "0x2",
                       "v" => "0xbe",
                       "value" => "0x0"
                     }
                   ],
                   "transactionsRoot" => "0xcd6c12fa43cd4e92ad5c0bf232b30488bbcbfe273c5b4af0366fced0767d54db",
                   "uncles" => []
                 }
               }

             %{
               id: id,
               method: "eth_getTransactionReceipt",
               params: [^transaction_hash]
             } ->
               %{
                 id: id,
                 jsonrpc: "2.0",
                 result: %{
                   "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                   "blockNumber" => "0x7",
                   "contractAddress" => nil,
                   "cumulativeGasUsed" => "0xc512",
                   "gasUsed" => "0xc512",
                   "logs" => [],
                   "logsBloom" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                   "root" => nil,
                   "status" => "0x1",
                   "transactionHash" => transaction_hash,
                   "transactionIndex" => "0x0"
                 }
               }

             %{id: id, method: "trace_block", params: [_]} ->
               %{id: id, result: []}

             %{id: id, jsonrpc: "2.0", method: "eth_getLogs"} ->
               %{id: id, jsonrpc: "2.0", result: []}
           end)}
        end)
      end

      assert {:ok, %{inserted: inserted}} = Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number)

      assert %{transactions: [inserted_transaction]} = inserted
      assert inserted_transaction.type == 2

      {:ok, max_fee} = Explorer.Chain.Wei.cast(max_fee_per_gas)
      assert inserted_transaction.max_fee_per_gas == max_fee

      {:ok, max_priority_fee} = Explorer.Chain.Wei.cast(max_priority_fee_per_gas)
      assert inserted_transaction.max_priority_fee_per_gas == max_priority_fee

      transaction_from_db = Transaction |> where([t], t.hash == ^transaction_hash) |> Explorer.Repo.one()
      assert transaction_from_db.type == 2
    end

    test "imports blocks with custom celo type (type 0x7c) transactions", %{
      block_fetcher: %Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher
    } do
      celo_token_address = insert(:contract_address)
      insert(:token, contract_address: celo_token_address)
      "0x" <> unprefixed_celo_token_address_hash = to_string(celo_token_address.hash)
      set_test_address(to_string(celo_token_address.hash))

      block_number = 7
      from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      to_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      transaction_hash = "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
      max_fee_per_gas = 343_434
      max_priority_fee_per_gas = 565_656

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, 4, fn requests, _options ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_getBlockByNumber", params: ["0x7", true]} ->
               %{
                 id: id,
                 result: %{
                   "author" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                   "difficulty" => "0x6bc767dd80781",
                   "extraData" => "0x5050594520737061726b706f6f6c2d6574682d7477",
                   "gasLimit" => "0x7a121d",
                   "gasUsed" => "0x79cbe9",
                   "hash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                   "logsBloom" =>
                     "0x044d42d008801488400e1809190200a80d06105bc0c4100b047895c0d518327048496108388040140010b8208006288102e206160e21052322440924002090c1c808a0817405ab238086d028211014058e949401012403210314896702d06880c815c3060a0f0809987c81044488292cc11d57882c912a808ca10471c84460460040000c0001012804022000a42106591881d34407420ba401e1c08a8d00a000a34c11821a80222818a4102152c8a0c044032080c6462644223104d618e0e544072008120104408205c60510542264808488220403000106281a0290404220112c10b080145028c8000300b18a2c8280701c882e702210b00410834840108084",
                   "miner" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
                   "mixHash" => "0xda53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                   "nonce" => "0x0946e5f01fce12bc",
                   "number" => block_number,
                   "parentHash" => "0x62543e836e0ef7edfa9e38f26526092c4be97efdf5ba9e0f53a4b0b7d5bc930a",
                   "receiptsRoot" => "0xa7d2b82bd8526de11736c18bd5cc8cfe2692106c4364526f3310ad56d78669c4",
                   "sha3Uncles" => "0x483a8a21a5825ad270f358b3ea56e060bbb8b3082d9a92ec8fa17a5c7e6fc1b6",
                   "size" => "0x544c",
                   "stateRoot" => "0x85daa9cd528004c1609d4cb3520fd958e85983bb4183124a4a9f7137fd39c691",
                   "timestamp" => "0x5c8bc76e",
                   "totalDifficulty" => "0x201a42c35142ae94458",
                   "transactions" => [
                     %{
                       "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                       "blockNumber" => block_number,
                       "chainId" => "0x4d",
                       "from" => from_address_hash,
                       "gas" => "0x47b760",
                       "gasPrice" => "0x174876e800",
                       "feeCurrency" => nil,
                       "gatewayFeeRecipient" => nil,
                       "gatewayFee" => "0x0",
                       "hash" => transaction_hash,
                       "input" => "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                       "maxFeePerGas" => max_fee_per_gas,
                       "maxPriorityFeePerGas" => max_priority_fee_per_gas,
                       "nonce" => "0x4",
                       "r" => "0xa7f8f45cce375bb7af8750416e1b03e0473f93c256da2285d1134fc97a700e01",
                       "s" => "0x1f87a076f13824f4be8963e3dffd7300dae64d5f23c9a062af0c6ead347c135f",
                       "to" => to_address_hash,
                       "transactionIndex" => "0x0",
                       "type" => "0x7c",
                       "v" => "0xbe",
                       "value" => "0x0"
                     }
                   ],
                   "transactionsRoot" => "0xcd6c12fa43cd4e92ad5c0bf232b30488bbcbfe273c5b4af0366fced0767d54db",
                   "uncles" => []
                 }
               }

             %{
               id: id,
               method: "eth_getTransactionReceipt",
               params: [^transaction_hash]
             } ->
               %{
                 id: id,
                 jsonrpc: "2.0",
                 result: %{
                   "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                   "blockNumber" => block_number,
                   "contractAddress" => nil,
                   "cumulativeGasUsed" => "0xc512",
                   "gasUsed" => "0xc512",
                   "logs" => [
                     %{
                       "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
                       "blockHash" => "0x1b6fb99af0b51af6685a191b2f7bcba684f8565629bf084c70b2530479407455",
                       "blockNumber" => "0x7",
                       "data" => "0x0000000000000000000000000000000000000000000000000000000000000f00",
                       "logIndex" => "0x0",
                       "topics" => [
                         "0x000000000000000000000000C257274276a4E539741Ca11b590B9447B26A8051"
                       ],
                       "transactionHash" => transaction_hash,
                       "transactionIndex" => "0x0",
                       "transactionLogIndex" => "0x0",
                       "type" => "mined"
                     }
                   ],
                   "logsBloom" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                   "root" => nil,
                   "status" => "0x1",
                   "transactionHash" => transaction_hash,
                   "transactionIndex" => "0x0"
                 }
               }

             %{id: id, method: "trace_block", params: [_]} ->
               %{id: id, result: []}

             %{id: id, jsonrpc: "2.0", method: "eth_getLogs"} ->
               %{id: id, jsonrpc: "2.0", result: []}
           end)}
        end)
      end

      assert {:ok, %{inserted: inserted}} = Fetcher.fetch_and_import_range(block_fetcher, block_number..block_number)

      assert %{transactions: [inserted_transaction]} = inserted
      # 0x7c
      assert inserted_transaction.type == 124

      {:ok, max_fee} = Explorer.Chain.Wei.cast(max_fee_per_gas)
      assert inserted_transaction.max_fee_per_gas == max_fee

      {:ok, max_priority_fee} = Explorer.Chain.Wei.cast(max_priority_fee_per_gas)
      assert inserted_transaction.max_priority_fee_per_gas == max_priority_fee

      transaction_from_db = Transaction |> where([t], t.hash == ^transaction_hash) |> Explorer.Repo.one()
      assert transaction_from_db.type == 124
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

  defp eth_block_number_fake_response(block_quantity) do
    %{
      id: 0,
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
        "miner" => "0x0000000000000000000000000000000000000000",
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
  end

  defp setup_mox(
         block_quantity,
         from_address_hash,
         to_address_hash,
         transaction_hash,
         unprefixed_celo_token_address_hash,
         event_first_topic,
         event_data,
         call_json_rpc_times
       ) do
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
                 "feeCurrency" => "0x0000000000000000000000000000000000000000",
                 "gatewayFeeRecipient" => "0x0000000000000000000000000000000000000000",
                 "gatewayFee" => "0x0",
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
    # async requests need to be grouped in one expect because the order is non-deterministic while multiple expect
    # calls on the same name/arity are used in order
    |> expect(:json_rpc, call_json_rpc_times, fn json, _options ->
      [request] = json

      case request do
        %{
          id: 0,
          jsonrpc: "2.0",
          method: "eth_getBlockByNumber",
          params: [^block_quantity, true]
        } ->
          {:ok,
           [
             %{
               id: 0,
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

        # read_addresses for 4 smart contracts in the fetcher
        %{id: id, jsonrpc: "2.0", method: "eth_call"} ->
          %{
            jsonrpc: "2.0",
            id: id,
            result: "0x000000000000000000000000" <> unprefixed_celo_token_address_hash
          }

        %{id: id, method: "eth_getBalance", params: [^to_address_hash, ^block_quantity]} ->
          {:ok, [%{id: id, jsonrpc: "2.0", result: "0x1"}]}

        %{id: id, method: "eth_getBalance", params: [^from_address_hash, ^block_quantity]} ->
          {:ok, [%{id: id, jsonrpc: "2.0", result: "0xd0d4a965ab52d8cd740000"}]}

        %{id: id, method: "eth_getBalance", params: [_, ^block_quantity]} ->
          {:ok, [%{id: id, jsonrpc: "2.0", result: "0x1"}]}

        %{id: id, method: "trace_replayBlockTransactions", params: [^block_quantity, ["trace"]]} ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: [
                 %{
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
                   "transactionHash" => transaction_hash,
                   "vmTrace" => nil
                 }
               ]
             }
           ]}

        %{id: id, method: "trace_block", params: [^block_quantity]} ->
          {:ok, [%{id: id, result: []}]}

        %{
          id: id,
          method: "eth_getTransactionReceipt",
          params: ["0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"]
        } ->
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
                     "data" => event_data,
                     "logIndex" => "0x0",
                     "topics" => [
                       event_first_topic,
                       "0x000000000000000000000000C257274276a4E539741Ca11b590B9447B26A8051"
                     ],
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

        %{id: id, jsonrpc: "2.0", method: "eth_getLogs"} ->
          {:ok, [%{id: id, jsonrpc: "2.0", result: []}]}
      end
    end)
  end
end
