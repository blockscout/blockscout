defmodule Indexer.Fetcher.TokenTransferTokenIdMigration.WorkerTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.TokenTransferTokenIdMigration.{LowestBlockNumberUpdater, Worker}
  alias Explorer.Utility.TokenTransferTokenIdMigratorProgress

  describe "Move TokenTransfer token_id to token_ids" do
    test "Move token_ids and update last processed block number" do
      insert(:token_transfer, block_number: 1, token_id: 1, transaction: insert(:transaction))
      insert(:token_transfer, block_number: 500, token_id: 2, transaction: insert(:transaction))
      insert(:token_transfer, block_number: 1000, token_id: 3, transaction: insert(:transaction))
      insert(:token_transfer, block_number: 1500, token_id: 4, transaction: insert(:transaction))
      insert(:token_transfer, block_number: 2000, token_id: 5, transaction: insert(:transaction))

      TokenTransferTokenIdMigratorProgress.update_last_processed_block_number(3000)
      LowestBlockNumberUpdater.start_link([])

      Worker.start_link(idx: 1, first_block: 0, last_block: 3000, step: 0, name: :worker_name)
      Process.sleep(200)

      token_transfers = Repo.all(Explorer.Chain.TokenTransfer)
      assert Enum.all?(token_transfers, fn tt -> is_nil(tt.token_id) end)

      expected_token_ids = [[Decimal.new(1)], [Decimal.new(2)], [Decimal.new(3)], [Decimal.new(4)], [Decimal.new(5)]]
      assert ^expected_token_ids = token_transfers |> Enum.map(& &1.token_ids) |> Enum.sort_by(&List.first/1)
    end
  end
end
