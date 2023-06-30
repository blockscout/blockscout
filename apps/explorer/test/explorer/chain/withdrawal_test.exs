defmodule Explorer.Chain.WithdrawalTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.Withdrawal

  describe "changeset/2" do
    test "with valid attributes" do
      assert %Changeset{valid?: true} =
               :withdrawal
               |> build()
               |> Withdrawal.changeset(%{})
    end

    test "with invalid attributes" do
      changeset = %Withdrawal{} |> Withdrawal.changeset(%{racecar: "yellow ham"})
      refute(changeset.valid?)
    end

    test "with duplicate information" do
      %Withdrawal{index: index} = insert(:withdrawal)

      assert {:error, %Changeset{valid?: false, errors: [index: {"has already been taken", _}]}} =
               %Withdrawal{}
               |> Withdrawal.changeset(params_for(:withdrawal, index: index))
               |> Repo.insert()
    end
  end

  describe "block_hash_to_withdrawals_query/1" do
    test "finds only withdrawals of this block" do
      withdrawal_a = insert(:withdrawal)
      withdrawal_b = insert(:withdrawal)

      results =
        Withdrawal.block_hash_to_withdrawals_query(withdrawal_a.block_hash)
        |> Repo.all()
        |> Enum.map(& &1.index)

      refute Enum.member?(results, withdrawal_b.index)
      assert Enum.member?(results, withdrawal_a.index)
    end

    test "order the results DESC by index" do
      block = insert(:block, withdrawals: insert_list(50, :withdrawal))

      results =
        Withdrawal.block_hash_to_withdrawals_query(block.hash)
        |> Repo.all()
        |> Enum.map(& &1.index)

      assert results |> Enum.sort(:desc) == results
    end
  end

  describe "address_hash_to_withdrawals_query/1" do
    test "finds only withdrawals of this address" do
      withdrawal_a = insert(:withdrawal)
      withdrawal_b = insert(:withdrawal)

      results =
        Withdrawal.address_hash_to_withdrawals_query(withdrawal_a.address_hash)
        |> Repo.all()
        |> Enum.map(& &1.index)

      refute Enum.member?(results, withdrawal_b.index)
      assert Enum.member?(results, withdrawal_a.index)
    end

    test "order the results DESC by index" do
      address = insert(:address, withdrawals: insert_list(50, :withdrawal))

      results =
        Withdrawal.address_hash_to_withdrawals_query(address.hash)
        |> Repo.all()
        |> Enum.map(& &1.index)

      assert results |> Enum.sort(:desc) == results
    end
  end
end
