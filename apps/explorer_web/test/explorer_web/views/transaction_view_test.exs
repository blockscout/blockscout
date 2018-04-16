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

    test "with receipt with status 0 with gas_used < gas" do
      gas = 2
      %Transaction{id: id} = insert(:transaction, gas: gas)
      insert(:receipt, gas_used: gas - 1, status: 0, transaction_id: id)

      transaction =
        Transaction
        |> Repo.get!(id)
        |> Repo.preload(:receipt)

      assert TransactionView.formatted_status(transaction) == "Failed"
    end

    test "with receipt with status 0 with gas <= gas_used" do
      gas = 2
      %Transaction{id: id} = insert(:transaction, gas: gas)
      insert(:receipt, gas_used: gas, status: 0, transaction_id: id)

      transaction =
        Transaction
        |> Repo.get!(id)
        |> Repo.preload(:receipt)

      assert TransactionView.formatted_status(transaction) == "Out of Gas"
    end

    test "with receipt with status 1" do
      gas = 2
      %Transaction{id: id} = insert(:transaction, gas: gas)
      insert(:receipt, gas_used: gas - 1, status: 1, transaction_id: id)

      transaction =
        Transaction
        |> Repo.get!(id)
        |> Repo.preload(:receipt)

      assert TransactionView.formatted_status(transaction) == "Success"
    end
  end
end
