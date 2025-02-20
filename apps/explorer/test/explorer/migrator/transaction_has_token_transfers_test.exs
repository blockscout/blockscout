defmodule Explorer.Migrator.TransactionHasTokenTransfersTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.Transaction
  alias Explorer.Migrator.{MigrationStatus, TransactionHasTokenTransfers}
  alias Explorer.Repo

  describe "Migrate transactions" do
    test "Set has_token_transfers for not processed transactions" do
      _transactions_without_token_transfers = insert_list(10, :transaction)

      Enum.each(0..10, fn _x ->
        transaction =
          :transaction
          |> insert()

        insert(:token_transfer, transaction: transaction)
      end)

      assert MigrationStatus.get_status("transaction_has_token_transfers") == nil

      TransactionHasTokenTransfers.start_link([])
      Process.sleep(100)

      Transaction
      |> Repo.all()
      |> Enum.group_by(& &1.has_token_transfers)
      |> Enum.map(fn
        {true, transactions_with_token_transfers} ->
          assert Enum.count(transactions_with_token_transfers) == 11

        {false, transactions_without_token_transfers} ->
          assert Enum.count(transactions_without_token_transfers) == 10
      end)

      assert MigrationStatus.get_status("transaction_has_token_transfers") == "completed"
    end
  end
end
