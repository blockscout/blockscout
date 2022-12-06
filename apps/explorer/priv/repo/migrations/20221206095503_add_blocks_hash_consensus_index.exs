defmodule Explorer.Repo.Migrations.AddBlocksHashConsensusIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :blocks,
        [:hash],
        name: :consensus_block_hashes,
        where: ~s(consensus)
      )
    )
  end
end
