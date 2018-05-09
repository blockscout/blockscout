defmodule Explorer.Indexer.BlockFetcherTest do
  # `async: false` due to use of named GenServer
  use Explorer.DataCase, async: false

  import ExUnit.CaptureLog

  alias Explorer.Chain.{Address, Block}
  alias Explorer.JSONRPC
  alias Explorer.Indexer.{BlockFetcher, Sequence}

  @tag capture_log: true

  describe "handle_info(:debug_count, state)" do
    setup do
      block = insert(:block)

      Enum.map(0..2, fn index ->
        transaction = insert(:transaction, block_hash: block.hash, index: index)
        receipt = insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)
        insert(:log, transaction_hash: receipt.transaction_hash)
        insert(:internal_transaction, transaction_hash: transaction.hash)
      end)

      :ok
    end

    test "without debug_logs" do
      assert capture_log_at_level(:debug, fn ->
               BlockFetcher.handle_info(:debug_count, %{debug_logs: false})
             end) == ""
    end

    test "with debug_logs" do
      log =
        capture_log_at_level(:debug, fn ->
          BlockFetcher.handle_info(:debug_count, %{debug_logs: true})
        end)

      assert log =~ "blocks: 4"
      assert log =~ "internal transactions: 3"
      assert log =~ "receipts: 6"
      assert log =~ "logs: 3"
      assert log =~ "addresses: 31"
    end
  end

  describe "import_range/3" do
    setup do
      start_supervised!({JSONRPC, []})
      start_supervised!({Task.Supervisor, name: Explorer.Indexer.TaskSupervisor})

      :ok
    end

    test "with single element range that is valid imports one block" do
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
                internal_transactions: [],
                logs: [],
                receipts: [],
                transactions: []
              }} = BlockFetcher.import_range({0, 0}, %{debug_logs: false}, sequence)

      assert Repo.aggregate(Block, :count, :hash) == 1
      assert Repo.aggregate(Address, :count, :hash) == 1
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
end
