defmodule Explorer.Repo.Migrations.AddBlockPendingParams do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add(:update_count, :integer, default: 0, null: false)
    end
  end
end
