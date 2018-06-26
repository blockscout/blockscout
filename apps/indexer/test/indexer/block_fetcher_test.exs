defmodule Indexer.BlockFetcherTest do
  # `async: false` due to use of named GenServer
  use Explorer.DataCase, async: false

  import ExUnit.CaptureLog

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

  @tag capture_log: true

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

  setup do
    %{variant: EthereumJSONRPC.config(:variant)}
  end

  describe "start_link/1" do
    test "starts fetching blocks from latest and goes down" do
      {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest")

      default_blocks_batch_size = BlockFetcher.default_blocks_batch_size()

      assert latest_block_number > default_blocks_batch_size

      assert Repo.aggregate(Block, :count, :hash) == 0

      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!()
      InternalTransactionFetcherCase.start_supervised!()
      start_supervised!(BlockFetcher)

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
    test "without debug_logs", %{state: state} do
      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!()
      InternalTransactionFetcherCase.start_supervised!()

      wait_for_tasks(InternalTransactionFetcher)
      wait_for_tasks(AddressBalanceFetcher)

      refute capture_log_at_level(:debug, fn ->
               Indexer.disable_debug_logs()
               BlockFetcher.handle_info(:debug_count, state)
             end) =~ @heading
    end

    @tag :capture_log
    test "with debug_logs", %{state: state} do
      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!()
      InternalTransactionFetcherCase.start_supervised!()

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

    setup do
      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!()
      InternalTransactionFetcherCase.start_supervised!()
      {:ok, state} = BlockFetcher.init([])

      %{state: state}
    end

    test "with single element range that is valid imports one block", %{state: state, variant: variant} do
      {:ok, sequence} = Sequence.start_link([], 0, 1)

      %{address_hash: address_hash, block_hash: block_hash} =
        case variant do
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

          _ ->
            raise ArgumenrError, "Unsupported variant (#{variant})"
        end

      assert {:ok,
              %{
                addresses: [^address_hash],
                blocks: [^block_hash],
                logs: [],
                transactions: []
              }} = BlockFetcher.import_range(0..0, state, sequence)

      wait_for_tasks(InternalTransactionFetcher)
      wait_for_tasks(AddressBalanceFetcher)

      assert Repo.aggregate(Block, :count, :hash) == 1
      assert Repo.aggregate(Address, :count, :hash) == 1

      address = Repo.get!(Address, address_hash)

      assert address.fetched_balance == %Wei{value: Decimal.new(0)}
      assert address.fetched_balance_block_number == 0
    end

    test "can import range with all synchronous imported schemas", %{state: state, variant: variant} do
      {:ok, sequence} = Sequence.start_link([], 0, 1)

      case variant do
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
                  }} = BlockFetcher.import_range(@first_full_block_number..@first_full_block_number, state, sequence)

          wait_for_tasks(InternalTransactionFetcher)
          wait_for_tasks(AddressBalanceFetcher)

          assert Repo.aggregate(Block, :count, :hash) == 1
          assert Repo.aggregate(Address, :count, :hash) == 2
          assert Repo.aggregate(Log, :count, :id) == 1
          assert Repo.aggregate(Transaction, :count, :hash) == 1

          first_address = Repo.get!(Address, first_address_hash)

          assert first_address.fetched_balance == %Wei{value: Decimal.new(1)}
          assert first_address.fetched_balance_block_number == @first_full_block_number

          second_address = Repo.get!(Address, second_address_hash)

          assert second_address.fetched_balance == %Wei{value: Decimal.new(252_460_837_000_000_000_000_000_000)}
          assert second_address.fetched_balance_block_number == @first_full_block_number

        _ ->
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

  defp state(_) do
    {:ok, state} = BlockFetcher.init([])

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
