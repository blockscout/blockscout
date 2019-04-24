defmodule Explorer.Repo.Migrations.AddIndexToConsensus do
  use Ecto.Migration

  def change do
    create(index(:blocks, [:consensus]))
  end
end
