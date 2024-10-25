defmodule Explorer.Repo.Scroll.Migrations.AddQueueIndexField do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:queue_index, :bigint, null: true)
    end
  end
end
