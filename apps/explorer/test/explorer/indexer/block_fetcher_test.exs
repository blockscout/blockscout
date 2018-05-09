defmodule Explorer.Indexer.BlockFetcherTest do
  # `async: false` due to use of named GenServer
  use Explorer.DataCase, async: false

  import ExUnit.CaptureLog

  alias Explorer.Indexer.BlockFetcher

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
