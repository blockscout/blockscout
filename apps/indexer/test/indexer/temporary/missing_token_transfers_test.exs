defmodule Indexer.Temporary.MissingTokenTransfersTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Block, Log, TokenTransfer}
  alias Indexer.Temporary.MissingTokenTransfers

  describe "clean_affected_data/2" do
    setup do
      # we need to know that the table exists or the DB transactions will fail
      Ecto.Adapters.SQL.query!(
        Repo,
        "CREATE TABLE IF NOT EXISTS blocks_to_invalidate_missing_tt (block_number integer, refetched boolean);"
      )

      :ok
    end

    test "removes consensus from blocks" do
      block = insert(:block)
      block_number = block.number

      MissingTokenTransfers.clean_affected_data([block_number])

      assert %{consensus: false} = from(b in Block, where: b.number == ^block_number) |> Repo.one()
    end

    test "deletes logs from transactions of blocks" do
      block = insert(:block)
      transaction = insert(:transaction) |> with_block(block)
      insert(:token_transfer, transaction: transaction)
      insert(:token_transfer, transaction: transaction)

      insert(:log, transaction: transaction)
      insert(:log, transaction: transaction)

      assert 2 =
               from(l in Log, where: l.transaction_hash == ^transaction.hash)
               |> Repo.aggregate(:count, :transaction_hash)

      block_number = block.number

      MissingTokenTransfers.clean_affected_data([block_number])

      assert 0 =
               from(l in Log, where: l.transaction_hash == ^transaction.hash)
               |> Repo.aggregate(:count, :transaction_hash)
    end

    test "deletes token_transfers from transactions of blocks" do
      block = insert(:block)
      transaction = insert(:transaction) |> with_block(block)
      insert(:token_transfer, transaction: transaction)
      insert(:token_transfer, transaction: transaction)

      assert 2 =
               from(t in TokenTransfer, where: t.transaction_hash == ^transaction.hash)
               |> Repo.aggregate(:count, :transaction_hash)

      block_number = block.number

      MissingTokenTransfers.clean_affected_data([block_number])

      assert 0 =
               from(t in TokenTransfer, where: t.transaction_hash == ^transaction.hash)
               |> Repo.aggregate(:count, :transaction_hash)
    end
  end
end
