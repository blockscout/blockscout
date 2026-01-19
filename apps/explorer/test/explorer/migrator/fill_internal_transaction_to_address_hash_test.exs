defmodule Explorer.Migrator.FillInternalTransactionToAddressHashTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.InternalTransaction
  alias Explorer.Migrator.{MigrationStatus, FillInternalTransactionToAddressHashWithCreatedContractAddressHash}
  alias Explorer.Repo

  setup_all do
    opts = Application.get_env(:explorer, FillInternalTransactionToAddressHashWithCreatedContractAddressHash)

    Application.put_env(:explorer, FillInternalTransactionToAddressHashWithCreatedContractAddressHash,
      batch_size: 1,
      concurrency: 1,
      timeout: 0
    )

    on_exit(fn ->
      Application.put_env(:explorer, FillInternalTransactionToAddressHashWithCreatedContractAddressHash, opts)
    end)
  end

  test "Fill to_address_hash with created_contract_address_hash" do
    Enum.each(1..3, fn index ->
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
        block_hash: transaction.block_hash
      )
    end)

    Enum.each(1..4, fn index ->
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction_create,
        transaction: transaction,
        index: index,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        transaction_index: transaction.index
      )
    end)

    internal_transactions_before = Repo.all(InternalTransaction)

    assert Enum.count(internal_transactions_before, fn it ->
             not is_nil(it.to_address_hash) and is_nil(it.created_contract_address_hash)
           end) == 3

    assert Enum.count(internal_transactions_before, fn it ->
             is_nil(it.to_address_hash) and not is_nil(it.created_contract_address_hash)
           end) == 4

    assert MigrationStatus.get_status("fill_internal_transaction_to_address_hash_with_created_contract_address_hash") ==
             nil

    FillInternalTransactionToAddressHashWithCreatedContractAddressHash.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where:
            ms.migration_name == ^"fill_internal_transaction_to_address_hash_with_created_contract_address_hash" and
              ms.status == "completed"
        )
      )
    end)

    internal_transactions_after = Repo.all(InternalTransaction)

    assert Enum.count(internal_transactions_after, fn it ->
             not is_nil(it.to_address_hash) and is_nil(it.created_contract_address_hash)
           end) == 3

    assert Enum.count(internal_transactions_after, fn it ->
             is_nil(it.to_address_hash) and not is_nil(it.created_contract_address_hash)
           end) == 0

    assert Enum.count(internal_transactions_after, fn it ->
             it.to_address_hash == it.created_contract_address_hash
           end) == 4
  end
end
