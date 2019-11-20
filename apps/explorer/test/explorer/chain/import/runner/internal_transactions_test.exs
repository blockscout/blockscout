defmodule Explorer.Chain.Import.Runner.InternalTransactionsTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.{Block, Data, Wei, PendingBlockOperation, Transaction, InternalTransaction}
  alias Explorer.Chain.Import.Runner.InternalTransactions

  describe "run/1" do
    test "transaction's status becomes :error when its internal_transaction has an error" do
      transaction = insert(:transaction) |> with_block(status: :ok)
      insert(:pending_block_operation, block_hash: transaction.block_hash, fetch_internal_transactions: true)

      assert :ok == transaction.status

      index = 0
      error = "Reverted"

      internal_transaction_changes = make_internal_transaction_changes(transaction, index, error)

      assert {:ok, _} = run_internal_transactions([internal_transaction_changes])

      assert :error == Repo.get(Transaction, transaction.hash).status
    end

    test "pending transactions don't get updated not its internal_transactions inserted" do
      transaction = insert(:transaction) |> with_block(status: :ok)
      pending = insert(:transaction)

      insert(:pending_block_operation, block_hash: transaction.block_hash, fetch_internal_transactions: true)

      assert :ok == transaction.status
      assert is_nil(pending.block_hash)

      index = 0

      transaction_changes = make_internal_transaction_changes(transaction, index, nil)
      pending_changes = make_internal_transaction_changes(pending, index, nil)

      assert {:ok, _} = run_internal_transactions([transaction_changes, pending_changes])

      assert Repo.exists?(from(i in InternalTransaction, where: i.transaction_hash == ^transaction.hash))

      assert PendingBlockOperation |> Repo.get(transaction.block_hash) |> is_nil()

      assert from(i in InternalTransaction, where: i.transaction_hash == ^pending.hash) |> Repo.one() |> is_nil()

      assert is_nil(Repo.get(Transaction, pending.hash).block_hash)
    end

    test "removes consensus to blocks where transactions are missing" do
      empty_block = insert(:block)
      pending = insert(:transaction)

      insert(:pending_block_operation, block_hash: empty_block.hash, fetch_internal_transactions: true)

      assert is_nil(pending.block_hash)

      full_block = insert(:block)
      inserted = insert(:transaction) |> with_block(full_block)

      insert(:pending_block_operation, block_hash: full_block.hash, fetch_internal_transactions: true)

      assert full_block.hash == inserted.block_hash

      index = 0

      pending_transaction_changes =
        pending
        |> make_internal_transaction_changes(index, nil)
        |> Map.put(:block_number, empty_block.number)

      transaction_changes = make_internal_transaction_changes(inserted, index, nil)

      assert {:ok, _} = run_internal_transactions([pending_transaction_changes, transaction_changes])

      assert from(i in InternalTransaction, where: i.transaction_hash == ^pending.hash) |> Repo.one() |> is_nil()

      assert %{consensus: false} = Repo.get(Block, empty_block.hash)
      assert not is_nil(Repo.get(PendingBlockOperation, empty_block.hash))

      assert from(i in InternalTransaction, where: i.transaction_hash == ^inserted.hash) |> Repo.one() |> is_nil() ==
               false

      assert %{consensus: true} = Repo.get(Block, full_block.hash)
      assert PendingBlockOperation |> Repo.get(full_block.hash) |> is_nil()
    end

    test "removes old records with the same primary key (transaction_hash, index)" do
      full_block = insert(:block)
      another_full_block = insert(:block)

      transaction = insert(:transaction) |> with_block(full_block)

      insert(:internal_transaction,
        index: 0,
        transaction: transaction,
        block_hash: another_full_block.hash,
        block_index: 0
      )

      insert(:pending_block_operation, block_hash: full_block.hash, fetch_internal_transactions: true)

      transaction_changes = make_internal_transaction_changes(transaction, 0, nil)

      assert {:ok, %{remove_left_over_internal_transactions: {1, nil}}} =
               run_internal_transactions([transaction_changes])

      assert from(i in InternalTransaction,
               where: i.transaction_hash == ^transaction.hash and i.block_hash == ^another_full_block.hash
             )
             |> Repo.one()
             |> is_nil()
    end

    test "removes consensus to blocks where not all transactions are filled" do
      full_block = insert(:block)
      transaction_a = insert(:transaction) |> with_block(full_block)
      transaction_b = insert(:transaction) |> with_block(full_block)

      insert(:pending_block_operation, block_hash: full_block.hash, fetch_internal_transactions: true)

      transaction_a_changes = make_internal_transaction_changes(transaction_a, 0, nil)

      assert {:ok, _} = run_internal_transactions([transaction_a_changes])

      assert from(i in InternalTransaction, where: i.transaction_hash == ^transaction_a.hash) |> Repo.one() |> is_nil()
      assert from(i in InternalTransaction, where: i.transaction_hash == ^transaction_b.hash) |> Repo.one() |> is_nil()

      assert %{consensus: false} = Repo.get(Block, full_block.hash)
      assert not is_nil(Repo.get(PendingBlockOperation, full_block.hash))
    end

    test "does not remove consensus when block is empty and no transactions are missing" do
      empty_block = insert(:block)

      insert(:pending_block_operation, block_hash: empty_block.hash, fetch_internal_transactions: true)

      full_block = insert(:block)
      inserted = insert(:transaction) |> with_block(full_block)

      insert(:pending_block_operation, block_hash: full_block.hash, fetch_internal_transactions: true)

      assert full_block.hash == inserted.block_hash

      index = 0

      transaction_changes = make_internal_transaction_changes(inserted, index, nil)
      empty_changes = make_empty_block_changes(empty_block.number)

      assert {:ok, _} = run_internal_transactions([empty_changes, transaction_changes])

      assert %{consensus: true} = Repo.get(Block, empty_block.hash)
      assert PendingBlockOperation |> Repo.get(empty_block.hash) |> is_nil()

      assert from(i in InternalTransaction, where: i.transaction_hash == ^inserted.hash) |> Repo.one() |> is_nil() ==
               false

      assert %{consensus: true} = Repo.get(Block, full_block.hash)
      assert PendingBlockOperation |> Repo.get(full_block.hash) |> is_nil()
    end
  end

  defp run_internal_transactions(changes_list, multi \\ Multi.new()) when is_list(changes_list) do
    multi
    |> InternalTransactions.run(changes_list, %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    })
    |> Repo.transaction()
  end

  defp make_empty_block_changes(block_number), do: %{block_number: block_number}

  defp make_internal_transaction_changes(transaction, index, error) do
    %{
      from_address_hash: insert(:address).hash,
      to_address_hash: insert(:address).hash,
      call_type: :call,
      gas: 22234,
      gas_used:
        if is_nil(error) do
          18920
        else
          nil
        end,
      input: %Data{bytes: <<1>>},
      output:
        if is_nil(error) do
          %Data{bytes: <<2>>}
        else
          nil
        end,
      index: index,
      trace_address: [],
      transaction_hash: transaction.hash,
      type: :call,
      value: Wei.from(Decimal.new(1), :wei),
      error: error,
      block_number: transaction.block_number
    }
  end
end
