defmodule Explorer.Chain.Cache.TransactionsTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Transactions
  alias Explorer.Repo

  @size 51

  describe "update/1" do
    test "adds a new value to a new cache with preloads" do
      transaction = insert(:transaction) |> preload_all()

      Transactions.update(transaction)

      assert Transactions.take(1) == [transaction]
    end

    test "adds several elements, removing the oldest when necessary" do
      transactions =
        1..@size
        |> Enum.map(fn n ->
          block = insert(:block, number: n)
          insert(:transaction) |> with_block(block)
        end)

      Transactions.update(transactions)

      assert Transactions.all() == Enum.reverse(preload_all(transactions))

      more_transactions =
        (@size + 1)..(@size + 10)
        |> Enum.map(fn n ->
          block = insert(:block, number: n)
          insert(:transaction) |> with_block(block)
        end)

      Transactions.update(more_transactions)

      kept_transactions =
        Enum.reverse(transactions ++ more_transactions)
        |> Enum.take(@size)
        |> preload_all()

      assert Transactions.take(@size) == kept_transactions
    end

    test "does not add a transaction too old when full" do
      transactions =
        10..(@size + 9)
        |> Enum.map(fn n ->
          block = insert(:block, number: n)
          insert(:transaction) |> with_block(block)
        end)

      Transactions.update(transactions)

      loaded_transactions = Enum.reverse(preload_all(transactions))
      assert Transactions.all() == loaded_transactions

      block = insert(:block, number: 1)
      insert(:transaction) |> with_block(block) |> Transactions.update()

      assert Transactions.all() == loaded_transactions
    end

    test "adds intermediate transactions" do
      blocks = 1..10 |> Map.new(fn n -> {n, insert(:block, number: n)} end)

      insert(:transaction) |> with_block(blocks[1]) |> Transactions.update()
      insert(:transaction) |> with_block(blocks[10]) |> Transactions.update()

      assert Transactions.size() == 2

      insert(:transaction) |> with_block(blocks[5]) |> Transactions.update()

      assert Transactions.size() == 3
    end
  end

  defp preload_all(transactions) when is_list(transactions) do
    Enum.map(transactions, &preload_all(&1))
  end

  defp preload_all(transaction) do
    Repo.preload(transaction, [
      :block,
      created_contract_address: :names,
      from_address: :names,
      to_address: :names,
      token_transfers: :token,
      token_transfers: :from_address,
      token_transfers: :to_address
    ])
  end
end
