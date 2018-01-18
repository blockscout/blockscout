defmodule Explorer.BlockTest do
  use Explorer.DataCase

  alias Explorer.Block

  describe "changeset/2" do
    test "with invalid attributes" do
      changeset = %Block{} |> Block.changeset(%{racecar: "yellow ham"})
      refute(changeset.valid?)
    end

    test "with duplicate information" do
      insert(:block, hash: "0x0")
      {:error, changeset} = %Block{} |> Block.changeset(params_for(:block, hash: "0x0")) |> Repo.insert
      refute changeset.valid?
      assert changeset.errors == [hash: {"has already been taken", []}]
    end

    test "rejects duplicate blocks with mixed case" do
      insert(:block, hash: "0xa")
      {:error, changeset} = %Block{} |> Block.changeset(params_for(:block, hash: "0xA")) |> Repo.insert
      refute changeset.valid?
      assert changeset.errors == [hash: {"has already been taken", []}]
    end
  end
end
