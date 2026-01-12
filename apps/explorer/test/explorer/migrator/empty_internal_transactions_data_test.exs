defmodule Explorer.Migrator.EmptyInternalTransactionsDataTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.{InternalTransaction, Wei}
  alias Explorer.Migrator.{EmptyInternalTransactionsData, MigrationStatus}
  alias Explorer.Repo

  describe "EmptyInternalTransactionsData" do
    test "Empties internal transactions trace_address and zero values" do
      Enum.each(1..8, fn i ->
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
          trace_address: [],
          value: if(i in [7, 8], do: 100, else: 0)
        )
      end)

      assert MigrationStatus.get_status("empty_internal_transactions_data") == nil
      assert Repo.aggregate(InternalTransaction, :count) == 8

      EmptyInternalTransactionsData.start_link([])
      Process.sleep(100)

      # Verify that trace_address and zero values are now nil
      internal_transactions =
        InternalTransaction
        |> Repo.all()
        |> Enum.sort_by(& &1.block_index)

      trace_addresses =
        internal_transactions
        |> Enum.map(& &1.trace_address)
        |> Enum.uniq()

      values =
        internal_transactions
        |> Enum.map(& &1.value)
        |> Enum.uniq()
        |> Enum.sort()

      assert [nil] == trace_addresses
      assert [nil, %Wei{value: Decimal.new("100")}] == values

      assert MigrationStatus.get_status("empty_internal_transactions_data") == "completed"
    end
  end
end
