defmodule Explorer.Migrator.FillInternalTransactionsAddressIdsTest do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.InternalTransaction
  alias Explorer.Migrator.{FillInternalTransactionsAddressIds, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.RemoveInternalTransactionsBlockHashTransactionHashBlockIndexError
  alias Explorer.Repo
  alias Explorer.Utility.AddressIdToAddressHash

  test "clears address hashes" do
    Enum.map(1..10, fn index ->
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: transaction,
        index: index,
        block_number: transaction.block_number,
        transaction_index: transaction.index
      )
    end)

    Enum.map(1..10, fn index ->
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction_create,
        transaction: transaction,
        index: index,
        block_number: transaction.block_number,
        transaction_index: transaction.index
      )
    end)

    MigrationStatus.set_status(
      RemoveInternalTransactionsBlockHashTransactionHashBlockIndexError.migration_name(),
      "completed"
    )

    assert MigrationStatus.get_status("fill_internal_transactions_address_ids") == nil

    FillInternalTransactionsAddressIds.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"fill_internal_transactions_address_ids" and ms.status == "completed"
        )
      )
    end)

    all_internal_transactions = Repo.all(InternalTransaction)

    assert Enum.all?(
             all_internal_transactions,
             &(is_nil(&1.from_address_hash) and is_nil(&1.to_address_hash) and is_nil(&1.created_contract_address_hash))
           )

    assert Enum.all?(
             all_internal_transactions,
             &(not is_nil(&1.from_address_id) or not is_nil(&1.to_address_id) or
                 not is_nil(&1.created_contract_address_id))
           )

    all_address_ids =
      all_internal_transactions
      |> Enum.flat_map(&[&1.from_address_id, &1.to_address_id, &1.created_contract_address_id])
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    existing_address_ids =
      AddressIdToAddressHash
      |> Repo.all()
      |> Enum.map(& &1.address_id)

    assert Enum.all?(all_address_ids, &Enum.member?(existing_address_ids, &1))
  end
end
