defmodule Explorer.Chain.Import.Runner.InternalTransactionsTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.{Block, Data, Wei, Transaction, InternalTransaction}
  alias Explorer.Chain.Import.Runner.InternalTransactions

  describe "run/1" do
    test "transaction's status becomes :error when its internal_transaction has an error" do
      transaction = insert(:transaction) |> with_block(status: :ok)

      assert :ok == transaction.status

      index = 0
      error = "Reverted"

      internal_transaction_changes = make_internal_transaction_changes(transaction.hash, index, error)

      assert {:ok, _} = run_internal_transactions([internal_transaction_changes])

      assert :error == Repo.get(Transaction, transaction.hash).status
    end

    test "pending transactions don't get updated not its internal_transactions inserted" do
      transaction = insert(:transaction) |> with_block(status: :ok)
      pending = insert(:transaction)

      assert :ok == transaction.status
      assert is_nil(pending.block_hash)

      index = 1

      transaction_changes = make_internal_transaction_changes(transaction.hash, index, nil)
      pending_changes = make_internal_transaction_changes(pending.hash, index, nil)

      assert {:ok, _} = run_internal_transactions([transaction_changes, pending_changes])

      assert %InternalTransaction{} =
               Repo.one(from(i in InternalTransaction, where: i.transaction_hash == ^transaction.hash))

      assert from(i in InternalTransaction, where: i.transaction_hash == ^pending.hash) |> Repo.one() |> is_nil()

      assert is_nil(Repo.get(Transaction, pending.hash).block_hash)
    end

    test "removes consensus to blocks where transactions are missing" do
      empty_block = insert(:block)
      pending = insert(:transaction)

      assert is_nil(pending.block_hash)

      full_block = insert(:block)
      inserted = insert(:transaction) |> with_block(full_block)

      assert full_block.hash == inserted.block_hash

      index = 1

      pending_transaction_changes =
        pending.hash
        |> make_internal_transaction_changes(index, nil)
        |> Map.put(:block_number, empty_block.number)

      transaction_changes =
        inserted.hash
        |> make_internal_transaction_changes(index, nil)
        |> Map.put(:block_number, full_block.number)

      multi =
        Multi.new()
        |> Multi.run(:internal_transactions_indexed_at_blocks, fn _, _ -> {:ok, [empty_block.hash, full_block.hash]} end)

      assert {:ok, _} = run_internal_transactions([pending_transaction_changes, transaction_changes], multi)

      assert from(i in InternalTransaction, where: i.transaction_hash == ^pending.hash) |> Repo.one() |> is_nil()

      assert %{consensus: false} = Repo.get(Block, empty_block.hash)

      assert from(i in InternalTransaction, where: i.transaction_hash == ^inserted.hash) |> Repo.one() |> is_nil() ==
               false

      assert %{consensus: true} = Repo.get(Block, full_block.hash)
    end

    test "does not remove consensus when block is empty and no transactions are missing" do
      empty_block = insert(:block)

      full_block = insert(:block)
      inserted = insert(:transaction) |> with_block(full_block)

      assert full_block.hash == inserted.block_hash

      index = 1

      transaction_changes =
        inserted.hash
        |> make_internal_transaction_changes(index, nil)
        |> Map.put(:block_number, full_block.number)

      multi =
        Multi.new()
        |> Multi.run(:internal_transactions_indexed_at_blocks, fn _, _ -> {:ok, [empty_block.hash, full_block.hash]} end)

      assert {:ok, _} = run_internal_transactions([transaction_changes], multi)

      assert %{consensus: true} = Repo.get(Block, empty_block.hash)

      assert from(i in InternalTransaction, where: i.transaction_hash == ^inserted.hash) |> Repo.one() |> is_nil() ==
               false

      assert %{consensus: true} = Repo.get(Block, full_block.hash)
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

  defp make_internal_transaction_changes(transaction_hash, index, error) do
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
      transaction_hash: transaction_hash,
      type: :call,
      value: Wei.from(Decimal.new(1), :wei),
      error: error
    }
  end
end
