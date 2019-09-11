defmodule Indexer.Temporary.InternalTransactionsBlockNumberTest do
  use Explorer.DataCase

  alias Explorer.Chain.Block
  alias Indexer.Temporary.InternalTransactionsBlockNumber

  @fetcher_name :internal_transactions_block_number

  describe "clean_affected_data/2" do
    setup do
      # we need to know that the table exists or the DB transactions will fail
      Ecto.Adapters.SQL.query!(
        Repo,
        "CREATE TABLE IF NOT EXISTS blocks_to_invalidate_wrong_int_txs_collation (block_number integer, refetched boolean);"
      )

      :ok
    end

    test "removes consensus from blocks" do
      block = insert(:block)
      transaction = insert(:transaction) |> with_block(block)

      block_number = block.number

      insert(:internal_transaction, transaction: transaction, block_number: block_number + 1, index: 0)

      InternalTransactionsBlockNumber.clean_affected_data([block_number])

      assert %{consensus: false} = from(b in Block, where: b.number == ^block_number) |> Repo.one()
    end
  end
end
