defmodule Explorer.BlockTest do
  use Explorer.DataCase

  alias Explorer.Block

  describe "changeset/2" do
    test "with invalid attributes" do
      changeset = Block.changeset(%Block{}, %{racecar: "yellow ham"})
      refute(changeset.valid?)
    end

    test "with duplicate information" do
      insert(:block, hash: "0x0")
      {:error, changeset} = Block.changeset(%Block{}, params_for(:block, hash: "0x0")) |> Repo.insert
      assert changeset.errors == [hash: {"has already been taken", []}]
      refute changeset.valid?
    end

    test "rejects duplicate blocks with mixed case" do
      insert(:block, hash: "0xa")
      {:error, changeset} = Block.changeset(%Block{}, params_for(:block, hash: "0xA")) |> Repo.insert
      assert changeset.errors == [hash: {"has already been taken", []}]
      refute changeset.valid?
    end
  end
end
