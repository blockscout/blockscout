defmodule Explorer.Migrator.EmptyInternalTransactionsTraceAddressTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.InternalTransaction
  alias Explorer.Migrator.{EmptyInternalTransactionsTraceAddress, MigrationStatus}
  alias Explorer.Repo

  describe "EmptyInternalTransactionsTraceAddress" do
    test "Empties internal transactions trace_address" do
      Enum.each(1..5, fn i ->
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
          trace_address: []
        )
      end)

      assert MigrationStatus.get_status("empty_internal_transactions_trace_address") == nil
      assert Repo.aggregate(InternalTransaction, :count) == 5

      EmptyInternalTransactionsTraceAddress.start_link([])
      Process.sleep(100)

      trace_addresses =
        InternalTransaction
        |> Repo.all()
        |> Enum.map(& &1.trace_address)
        |> Enum.uniq()

      assert [nil] == trace_addresses

      assert MigrationStatus.get_status("empty_internal_transactions_trace_address") == "completed"
    end
  end
end
