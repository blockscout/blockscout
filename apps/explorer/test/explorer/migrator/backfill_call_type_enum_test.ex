defmodule Explorer.Migrator.BackfillCallTypeEnumTest do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.InternalTransaction
  alias Explorer.Migrator.{BackfillCallTypeEnum, MigrationStatus}
  alias Explorer.Repo

  test "updates call_type_enum and call_type fields" do
    Enum.each(1..10, fn index ->
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :internal_transaction,
        transaction: transaction,
        index: index,
        block_number: transaction.block_number,
        transaction_index: transaction.index,
        block_hash: transaction.block_hash,
        block_index: index,
        call_type: :call
      )
    end)

    assert MigrationStatus.get_status("backfill_call_type_enum") == nil

    BackfillCallTypeEnum.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"backfill_call_type_enum" and ms.status == "completed"
        )
      )
    end)

    InternalTransaction
    |> Repo.all()
    |> Enum.each(fn internal_transaction ->
      assert is_nil(internal_transaction.call_type)
      assert internal_transaction.call_type_enum == :call
    end)

    assert BackgroundMigrations.get_backfill_call_type_enum_finished() == true
  end
end
