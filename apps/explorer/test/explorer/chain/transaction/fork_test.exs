defmodule Explorer.Chain.Transaction.ForkTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.Transaction.Fork

  doctest Fork

  test "a transaction fork cannot be inserted if the corresponding transaction does not exist" do
    assert %Changeset{valid?: true} = changeset = Fork.changeset(%Fork{}, params_for(:transaction_fork))

    assert {:error, %Changeset{errors: [transaction: {"does not exist", _}]}} = Repo.insert(changeset)
  end

  test "a transaction fork cannot be inserted if the corresponding uncle does not exist" do
    transaction = insert(:transaction)

    assert %Changeset{valid?: true} =
             changeset = Fork.changeset(%Fork{}, %{hash: transaction.hash, index: 0, uncle_hash: block_hash()})

    assert {:error, %Changeset{errors: [uncle: {"does not exist", _}]}} = Repo.insert(changeset)
  end
end
