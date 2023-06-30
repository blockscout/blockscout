defmodule Explorer.Repo.Migrations.CreateMissingBlockRanges do
  use Ecto.Migration

  def change do
    create table(:missing_block_ranges) do
      add(:from_number, :integer)
      add(:to_number, :integer)
    end

    create(index(:missing_block_ranges, ["from_number DESC"]))
    create(unique_index(:missing_block_ranges, [:from_number, :to_number]))
  end
end
