defmodule ExplorerWeb.TransactionViewTest do
  use ExplorerWeb.ConnCase, async: true

  alias Explorer.Chain.Transaction
  alias Explorer.Repo
  alias ExplorerWeb.TransactionView

  describe "formatted_status/1" do
    test "without receipt" do
      transaction =
        :transaction
        |> insert()
        |> Repo.preload(:receipt)

      assert TransactionView.formatted_status(transaction) == "Pending"
    end

    test "with receipt with status :error with gas_used < gas" do
      gas = 2
      block = insert(:block)
      %Transaction{hash: hash, index: index} = insert(:transaction, block_hash: block.hash, gas: gas, index: 0)
      insert(:receipt, gas_used: gas - 1, status: :error, transaction_hash: hash, transaction_index: index)

      transaction =
        Transaction
        |> Repo.get!(hash)
        |> Repo.preload(:receipt)

      assert TransactionView.formatted_status(transaction) == "Failed"
    end

    test "with receipt with status :error with gas <= gas_used" do
      gas = 2
      block = insert(:block)
      %Transaction{hash: hash, index: index} = insert(:transaction, block_hash: block.hash, gas: gas, index: 0)
      insert(:receipt, gas_used: gas, status: 0, transaction_hash: hash, transaction_index: index)

      transaction =
        Transaction
        |> Repo.get!(hash)
        |> Repo.preload(:receipt)

      assert TransactionView.formatted_status(transaction) == "Out of Gas"
    end

    test "with receipt with status :ok" do
      gas = 2
      block = insert(:block)
      %Transaction{hash: hash, index: index} = insert(:transaction, block_hash: block.hash, gas: gas, index: 0)
      insert(:receipt, gas_used: gas - 1, status: :ok, transaction_hash: hash, transaction_index: index)

      transaction =
        Transaction
        |> Repo.get!(hash)
        |> Repo.preload(:receipt)

      assert TransactionView.formatted_status(transaction) == "Success"
    end
  end
end
