defmodule Explorer.Migrator.DeleteZeroValueInternalTransactionsTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.InternalTransaction
  alias Explorer.Migrator.{DeleteZeroValueInternalTransactions, MigrationStatus}
  alias Explorer.Repo
  alias Explorer.Utility.{AddressIdToAddressHash, InternalTransactionsAddressPlaceholder}

  test "Deletes zero value calls" do
    address_1 = insert(:address)
    address_2 = insert(:address)
    address_3 = insert(:address)

    block = insert(:block, timestamp: Timex.shift(Timex.now(), days: -40))

    Enum.map(1..3, fn i ->
      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(:internal_transaction,
        index: 10,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        from_address: address_1,
        to_address: address_2,
        block_index: i,
        type: :call,
        value: 0
      )
    end)

    Enum.map(1..4, fn i ->
      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(:internal_transaction,
        index: 10,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        from_address: address_2,
        to_address: address_3,
        block_index: i + 3,
        type: :call,
        value: 0
      )
    end)

    Enum.map(1..5, fn i ->
      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(:internal_transaction,
        index: 10,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        from_address: address_3,
        to_address: address_1,
        block_index: i + 7,
        type: :call,
        value: 0
      )
    end)

    Enum.map(1..4, fn i ->
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        index: 10,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        block_index: i,
        type: :call,
        value: 1
      )
    end)

    Enum.map(1..5, fn i ->
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction_create,
        index: 10,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        block_index: i,
        value: 0
      )
    end)

    Enum.map(1..6, fn i ->
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        index: 10,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        block_index: i,
        type: :call,
        value: 0
      )
    end)

    assert MigrationStatus.get_status("delete_zero_value_internal_transactions") == nil

    DeleteZeroValueInternalTransactions.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"delete_zero_value_internal_transactions" and ms.status == "completed"
        )
      )
    end)

    all_internal_transactions = Repo.all(InternalTransaction)

    assert Enum.count(all_internal_transactions) == 15

    non_zero_value_calls =
      Enum.filter(all_internal_transactions, &(&1.type == :call and not Decimal.eq?(&1.value.value, 0)))

    non_calls = Enum.filter(all_internal_transactions, &(&1.type != :call))

    recent_zero_value_calls =
      Enum.filter(all_internal_transactions, &(&1.type == :call and Decimal.eq?(&1.value.value, 0)))

    assert Enum.count(non_zero_value_calls) == 4
    assert Enum.all?(non_zero_value_calls, &(not Decimal.eq?(&1.value.value, 0)))

    assert Enum.count(non_calls) == 5

    assert Enum.count(recent_zero_value_calls) == 6

    id_to_hashes = Repo.all(AddressIdToAddressHash)

    assert length(id_to_hashes) == 3

    assert %{address_id: address_1_id} = Enum.find(id_to_hashes, &(&1.address_hash == address_1.hash))
    assert %{address_id: address_2_id} = Enum.find(id_to_hashes, &(&1.address_hash == address_2.hash))
    assert %{address_id: address_3_id} = Enum.find(id_to_hashes, &(&1.address_hash == address_3.hash))

    placeholders = Repo.all(InternalTransactionsAddressPlaceholder)

    assert length(placeholders) == 3

    assert Enum.any?(placeholders, fn p ->
             p.address_id == address_1_id and p.block_number == block.number and p.count_tos == 5 and p.count_froms == 3
           end)

    assert Enum.any?(placeholders, fn p ->
             p.address_id == address_2_id and p.block_number == block.number and p.count_tos == 3 and p.count_froms == 4
           end)

    assert Enum.any?(placeholders, fn p ->
             p.address_id == address_3_id and p.block_number == block.number and p.count_tos == 4 and p.count_froms == 5
           end)
  end
end
