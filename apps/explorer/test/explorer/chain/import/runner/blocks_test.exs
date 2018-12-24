defmodule Explorer.Chain.Import.Runner.BlocksTest do
  use Explorer.DataCase

  import Ecto.Query, only: [from: 2, select: 2, where: 2]

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.{Blocks, Transaction}
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Repo

  describe "run/1" do
    setup do
      block = insert(:block, consensus: true)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      %{consensus_block: block, transaction: transaction}
    end

    test "derive_transaction_forks replaces hash on conflicting (uncle_hash, index)", %{
      consensus_block: %Block{hash: block_hash, miner_hash: miner_hash, number: block_number},
      transaction: transaction
    } do
      block_params =
        params_for(:block, hash: block_hash, miner_hash: miner_hash, number: block_number, consensus: false)

      %Ecto.Changeset{valid?: true, changes: block_changes} = Block.changeset(%Block{}, block_params)
      changes_list = [block_changes]

      timestamp = DateTime.utc_now()
      options = %{timestamps: %{inserted_at: timestamp, updated_at: timestamp}}

      assert Repo.aggregate(from(transaction in Transaction, where: is_nil(transaction.block_number)), :count, :hash) ==
               0

      assert count(Transaction.Fork) == 0

      # re-org consensus_block to uncle

      assert {:ok, %{derive_transaction_forks: [_]}} =
               Multi.new()
               |> Blocks.run(changes_list, options)
               |> Repo.transaction()

      assert Repo.aggregate(where(Block, consensus: false), :count, :number) == 1

      assert Repo.aggregate(from(transaction in Transaction, where: is_nil(transaction.block_number)), :count, :hash) ==
               1

      assert count(Transaction.Fork) == 1

      non_consensus_transaction = Repo.get(Transaction, transaction.hash)
      non_consensus_block = Repo.get(Block, block_hash)

      # Make it consensus again
      new_consensus_block =
        non_consensus_block
        |> Block.changeset(%{consensus: true})
        |> Repo.update!()

      with_block(non_consensus_transaction, new_consensus_block)

      ctid = Repo.one!(from(transaction_fork in Transaction.Fork, select: "ctid"))

      assert Repo.aggregate(from(transaction in Transaction, where: is_nil(transaction.block_number)), :count, :hash) ==
               0

      assert {:ok, %{derive_transaction_forks: []}} =
               Multi.new()
               |> Blocks.run(changes_list, options)
               |> Repo.transaction()

      assert Repo.one!(from(transaction_fork in Transaction.Fork, select: "ctid")) == ctid,
             "Tuple was written even though it is not distinct"
    end
  end

  defp count(schema) do
    Repo.one!(select(schema, fragment("COUNT(*)")))
  end
end
