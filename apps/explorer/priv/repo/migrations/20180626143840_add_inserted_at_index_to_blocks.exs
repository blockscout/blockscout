defmodule Explorer.Repo.Migrations.AddInsertedAtIndexToBlocks do
  use Ecto.Migration

  def change do
    create(index(:blocks, :inserted_at))
  end
end
