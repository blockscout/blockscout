defmodule Explorer.Repo.Migrations.MissingBlockRangesAddPriority do
  use Ecto.Migration

  def change do
    alter table(:missing_block_ranges) do
      add(:priority, :smallint)
    end

    drop(index(:missing_block_ranges, ["from_number DESC"]))
    create(index(:missing_block_ranges, ["priority DESC NULLS LAST", "from_number DESC"]))
  end
end
