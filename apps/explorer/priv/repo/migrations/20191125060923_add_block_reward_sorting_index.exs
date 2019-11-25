defmodule Explorer.Repo.Migrations.AddBlockRewardSortingIndex do
  use Ecto.Migration

  def change do
    drop(index(:blocks, [:number], name: "blocks_number_index"))

    create(
      index(
        :blocks,
        ["number DESC"],
        name: "blocks_number_index"
      )
    )
  end
end
