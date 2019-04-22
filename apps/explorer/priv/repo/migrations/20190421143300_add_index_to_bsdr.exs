defmodule Explorer.Repo.Migrations.AddIndexToBsdr do
  use Ecto.Migration

  def change do
    alter table(:block_second_degree_relations) do
      # Null for old relations without fetched index
      add(:index, :integer, null: true)
    end
  end
end
