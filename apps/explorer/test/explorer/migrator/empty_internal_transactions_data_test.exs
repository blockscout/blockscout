defmodule Explorer.Migrator.EmptyInternalTransactionsDataTest do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.{InternalTransaction, Wei}
  alias Explorer.Migrator.{EmptyInternalTransactionsData, MigrationStatus}
  alias Explorer.Repo

  test "empties data" do
    _trace_address_internal_transactions = insert_batch_of_internal_transactions(trace_address: [0])
    _value_internal_transactions = insert_batch_of_internal_transactions(value: 0)
    _call_type_internal_transactions = insert_batch_of_internal_transactions(call_type: :call)
    %{id: transaction_error_id} = insert(:transaction_error, message: "error")
    _error_internal_transactions = insert_batch_of_internal_transactions(error: "error")

    assert MigrationStatus.get_status("empty_internal_transactions_data") == nil

    EmptyInternalTransactionsData.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"empty_internal_transactions_data" and ms.status == "completed"
        )
      )
    end)

    all_internal_transactions = Repo.all(InternalTransaction)

    assert Enum.all?(all_internal_transactions, &is_nil(&1.trace_address))
    assert Enum.all?(all_internal_transactions, &(is_nil(&1.value) or Decimal.gt?(Wei.to(&1.value, :wei), 0)))
    assert Enum.all?(all_internal_transactions, &is_nil(&1.call_type))
    refute Enum.all?(all_internal_transactions, &is_nil(&1.call_type_enum))
    assert Enum.all?(all_internal_transactions, &is_nil(&1.error))
    refute Enum.all?(all_internal_transactions, &is_nil(&1.error_id))
    assert Enum.all?(all_internal_transactions, &(is_nil(&1.error_id) or &1.error_id == transaction_error_id))

    assert BackgroundMigrations.get_empty_internal_transactions_data_finished() == true
  end

  defp insert_batch_of_internal_transactions(additional_fields) do
    Enum.map(1..10, fn index ->
      transaction =
        :transaction
        |> insert()
        |> with_block()

      base_fields = [
        transaction: transaction,
        index: index,
        block_number: transaction.block_number,
        transaction_index: transaction.index,
        block_hash: transaction.block_hash,
        block_index: index
      ]

      insert(:internal_transaction, Keyword.merge(base_fields, additional_fields))
    end)
  end
end
