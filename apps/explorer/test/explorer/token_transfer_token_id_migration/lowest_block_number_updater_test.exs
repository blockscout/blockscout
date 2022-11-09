defmodule Explorer.TokenTransferTokenIdMigration.LowestBlockNumberUpdaterTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.TokenTransferTokenIdMigration.LowestBlockNumberUpdater
  alias Explorer.Utility.TokenTransferTokenIdMigratorProgress

  describe "Add range and update last processed block number" do
    test "add_range/2" do
      TokenTransferTokenIdMigratorProgress.update_last_processed_block_number(2000)
      LowestBlockNumberUpdater.start_link([])

      LowestBlockNumberUpdater.add_range(1000, 500)
      LowestBlockNumberUpdater.add_range(1500, 1001)
      Process.sleep(10)

      assert %{last_processed_block_number: 2000, processed_ranges: [1500..500//-1]} =
               :sys.get_state(LowestBlockNumberUpdater)

      assert %{last_processed_block_number: 2000} = Repo.one(TokenTransferTokenIdMigratorProgress)

      LowestBlockNumberUpdater.add_range(499, 300)
      LowestBlockNumberUpdater.add_range(299, 0)
      Process.sleep(10)

      assert %{last_processed_block_number: 2000, processed_ranges: [1500..0//-1]} =
               :sys.get_state(LowestBlockNumberUpdater)

      assert %{last_processed_block_number: 2000} = Repo.one(TokenTransferTokenIdMigratorProgress)

      LowestBlockNumberUpdater.add_range(1999, 1501)
      Process.sleep(10)
      assert %{last_processed_block_number: 0, processed_ranges: []} = :sys.get_state(LowestBlockNumberUpdater)
      assert %{last_processed_block_number: 0} = Repo.one(TokenTransferTokenIdMigratorProgress)
    end
  end
end
