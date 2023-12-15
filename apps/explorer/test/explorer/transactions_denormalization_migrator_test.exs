defmodule Explorer.TransactionsDenormalizationMigratorTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Transaction
  alias Explorer.{Repo, TransactionsDenormalizationMigrator}

  describe "Migrate transactions" do
    test "Set block_consensus and block_timestamp for not processed transactions" do
      Enum.each(0..10, fn _x ->
        transaction =
          :transaction
          |> insert()
          |> with_block(block_timestamp: nil, block_consensus: nil)

        assert %{block_consensus: nil, block_timestamp: nil, block: %{consensus: consensus, timestamp: timestamp}} =
                 transaction

        assert not is_nil(consensus)
        assert not is_nil(timestamp)
      end)

      TransactionsDenormalizationMigrator.start_link([])
      Process.sleep(100)

      Transaction
      |> Repo.all()
      |> Repo.preload(:block)
      |> Enum.each(fn t ->
        assert %{
                 block_consensus: consensus,
                 block_timestamp: timestamp,
                 block: %{consensus: consensus, timestamp: timestamp}
               } = t
      end)
    end
  end
end
