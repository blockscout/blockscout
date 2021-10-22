defmodule Explorer.Repo.Migrations.AddIsEmptyIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :blocks,
        ~w(consensus)a,
        name: :empty_consensus_blocks,
        where: "is_empty IS NULL"
      )
    )
  end
end
