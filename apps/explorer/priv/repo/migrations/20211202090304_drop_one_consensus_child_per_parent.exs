defmodule Explorer.Repo.Migrations.DropOneConsensusChildPerParent do
  use Ecto.Migration

  def change do
    drop(index(:blocks, [:parent_hash], where: ~s(consensus), name: :one_consensus_child_per_parent))
    create(index(:blocks, [:parent_hash], where: ~s(consensus)))
  end
end
