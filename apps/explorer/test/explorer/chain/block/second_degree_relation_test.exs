defmodule Explorer.Chain.Block.SecondDegreeRelationTest do
  use Explorer.DataCase, async: true

  alias Ecto.Changeset
  alias Explorer.Chain.Block

  describe "changeset/2" do
    test "requires hash, nephew_hash and index" do
      assert %Changeset{valid?: false} =
               changeset = Block.SecondDegreeRelation.changeset(%Block.SecondDegreeRelation{}, %{})

      assert changeset_errors(changeset) == %{
               nephew_hash: ["can't be blank"],
               uncle_hash: ["can't be blank"],
               index: ["can't be blank"]
             }

      assert %Changeset{valid?: true} =
               Block.SecondDegreeRelation.changeset(%Block.SecondDegreeRelation{}, %{
                 nephew_hash: block_hash(),
                 uncle_hash: block_hash(),
                 index: 0
               })
    end

    test "allows uncle_fetched_at" do
      assert %Changeset{changes: %{uncle_fetched_at: _}, valid?: true} =
               Block.SecondDegreeRelation.changeset(%Block.SecondDegreeRelation{}, %{
                 nephew_hash: block_hash(),
                 uncle_hash: block_hash(),
                 index: 0,
                 uncle_fetched_at: DateTime.utc_now()
               })
    end

    test "enforces foreign key constraint on nephew_hash" do
      assert {:error, %Changeset{valid?: false} = changeset} =
               %Block.SecondDegreeRelation{}
               |> Block.SecondDegreeRelation.changeset(%{nephew_hash: block_hash(), uncle_hash: block_hash(), index: 0})
               |> Repo.insert()

      assert changeset_errors(changeset) == %{nephew_hash: ["does not exist"]}
    end

    test "enforces unique constraints on {nephew_hash, uncle_hash}" do
      %Block.SecondDegreeRelation{nephew_hash: nephew_hash, uncle_hash: hash} = insert(:block_second_degree_relation)

      assert {:error, %Changeset{valid?: false} = changeset} =
               %Block.SecondDegreeRelation{}
               |> Block.SecondDegreeRelation.changeset(%{nephew_hash: nephew_hash, uncle_hash: hash, index: 0})
               |> Repo.insert()

      assert changeset_errors(changeset) == %{uncle_hash: ["has already been taken"]}
    end
  end
end
