defmodule Explorer.Migrator.EmptyInternalTransactionsZeroValuesTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.{InternalTransaction, Wei}
  alias Explorer.Migrator.{EmptyInternalTransactionsZeroValues, MigrationStatus}
  alias Explorer.Repo

  describe "EmptyInternalTransactionsZeroValues" do
    test "Empties internal transactions zero values" do
      Enum.each(1..6, fn i ->
        block = insert(:block)
        transaction = :transaction |> insert() |> with_block(block, status: :ok)

        insert(:internal_transaction,
          index: 10,
          transaction: transaction,
          block: block,
          block_number: block.number,
          block_index: i,
          transaction_index: 0,
          error: nil,
          value: if(i == 6, do: 100, else: 0)
        )
      end)

      assert MigrationStatus.get_status("empty_internal_transactions_zero_values") == nil
      assert Repo.aggregate(InternalTransaction, :count) == 6

      EmptyInternalTransactionsZeroValues.start_link([])
      Process.sleep(100)

      values =
        InternalTransaction
        |> Repo.all()
        |> Enum.map(& &1.value)
        |> Enum.uniq()
        |> Enum.sort()

      assert [nil, %Wei{value: Decimal.new("100")}] == values

      assert MigrationStatus.get_status("empty_internal_transactions_zero_values") == "completed"
    end
  end
end
