defmodule Explorer.Repo.Migrations.AddBlockIsEmptyFlag do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add(:is_empty, :bool, null: true)
    end

    create(index(:blocks, [:is_empty]))
  end
end
