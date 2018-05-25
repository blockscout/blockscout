defmodule Explorer.Indexer.BlockFetcherTest do
  # `async: false` due to use of named GenServer
  use Explorer.DataCase, async: false

  import ExUnit.CaptureLog

  alias Explorer.Chain.{Address, Block, Log, Transaction}
  alias Explorer.Indexer
  alias Explorer.Indexer.{AddressBalanceFetcherCase, BlockFetcher, InternalTransactionFetcherCase, Sequence}

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

  describe "start_link/1" do
    test "starts fetching blocks from Genesis" do
      assert Repo.aggregate(Block, :count, :hash) == 0

      start_supervised!({Task.Supervisor, name: Explorer.Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!()
      InternalTransactionFetcherCase.start_supervised!()
      start_supervised!(BlockFetcher)

      wait(fn ->
        Repo.one!(from(block in Block, where: block.number == @first_full_block_number))
      end)

      assert Repo.aggregate(Block, :count, :hash) >= @first_full_block_number
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

        insert(:log, transaction_hash: transaction.hash)
        insert(:internal_transaction, transaction_hash: transaction.hash, index: 0)
      end)

      :ok
    end

    test "without debug_logs", %{state: state} do
      assert capture_log_at_level(:debug, fn ->
               Indexer.disable_debug_logs()
               BlockFetcher.handle_info(:debug_count, state)
             end) == ""
    end

    test "with debug_logs", %{state: state} do
      AddressBalanceFetcherCase.start_supervised!()
      InternalTransactionFetcherCase.start_supervised!()

      log =
        capture_log_at_level(:debug, fn ->
          Indexer.enable_debug_logs()
          BlockFetcher.handle_info(:debug_count, state)
        end)

      assert log =~ "blocks: 4"
      assert log =~ "internal transactions: 3"
      assert log =~ "logs: 3"
      assert log =~ "addresses: 31"
    end
  end

  describe "import_range/3" do
    setup :state

    setup do
      start_supervised!({Task.Supervisor, name: Explorer.Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!()
      InternalTransactionFetcherCase.start_supervised!()
      {:ok, state} = BlockFetcher.init(debug_logs: false)

      %{state: state}
    end

    test "with single element range that is valid imports one block", %{state: state} do
      {:ok, sequence} = Sequence.start_link([], 0, 1)

      assert {:ok,
              %{
                addresses: [
                  %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
                  }
                ],
                blocks: [
                  %Explorer.Chain.Hash{
                    byte_count: 32,
                    bytes:
                      <<91, 40, 193, 191, 211, 161, 82, 48, 201, 164, 107, 57, 156, 208, 249, 166, 146, 13, 67, 46, 133,
                        56, 28, 198, 161, 64, 176, 110, 132, 16, 17, 47>>
                  }
                ],
                logs: [],
                transactions: []
              }} = BlockFetcher.import_range({0, 0}, state, sequence)

      assert Repo.aggregate(Block, :count, :hash) == 1
      assert Repo.aggregate(Address, :count, :hash) == 1
    end

    test "can import range with all synchronous imported schemas", %{state: state} do
      {:ok, sequence} = Sequence.start_link([], 0, 1)

      assert {:ok,
              %{
                addresses: [
                  %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes:
                      <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65, 91>>
                  },
                  %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes:
                      <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122, 202>>
                  }
                ],
                blocks: [
                  %Explorer.Chain.Hash{
                    byte_count: 32,
                    bytes:
                      <<246, 180, 184, 200, 141, 243, 235, 210, 82, 236, 71, 99, 40, 51, 77, 192, 38, 207, 102, 96, 106,
                        132, 251, 118, 155, 61, 60, 188, 204, 132, 113, 189>>
                  }
                ],
                logs: [
                  %{
                    index: 0,
                    transaction_hash: %Explorer.Chain.Hash{
                      byte_count: 32,
                      bytes:
                        <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                          101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                    }
                  }
                ],
                transactions: [
                  %Explorer.Chain.Hash{
                    byte_count: 32,
                    bytes:
                      <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                        101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                  }
                ]
              }} = BlockFetcher.import_range({@first_full_block_number, @first_full_block_number}, state, sequence)

      assert Repo.aggregate(Block, :count, :hash) == 1
      assert Repo.aggregate(Address, :count, :hash) == 2
      assert Repo.aggregate(Log, :count, :id) == 1
      assert Repo.aggregate(Transaction, :count, :hash) == 1
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

  defp wait(producer) do
    producer.()
  rescue
    Ecto.NoResultsError ->
      Process.sleep(100)
      wait(producer)
  end
end
